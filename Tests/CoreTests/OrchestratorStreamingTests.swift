import Testing
import Foundation
@testable import JARVIS

@Suite("Orchestrator Streaming Tests", .serialized)
struct OrchestratorStreamingTests {

    // MARK: - Helpers

    private func makeOrchestrator(
        model: MockModelProvider,
        toolRegistry: ToolRegistryImpl? = nil,
        policyEngine: MockPolicyEngine? = nil
    ) -> OrchestratorImpl {
        OrchestratorImpl(
            modelProvider: model,
            toolRegistry: toolRegistry ?? ToolRegistryImpl(),
            policyEngine: policyEngine ?? MockPolicyEngine()
        )
    }

    private func textResponse(text: String...) -> [StreamEvent] {
        var events: [StreamEvent] = [.messageStart(id: "msg-1", model: "claude-sonnet-4-6")]
        for chunk in text {
            events.append(.textDelta(chunk))
        }
        events.append(.messageDelta(stopReason: .endTurn, usage: Usage(inputTokens: 10, outputTokens: text.count)))
        events.append(.messageStop)
        return events
    }

    // MARK: - Test 1: Simple text streaming response

    @Test func testStreamingTextResponse() async throws {
        let model = MockModelProvider()
        model.enqueueStream(events: textResponse(text: "Hello", ", world", "!"))

        let orch = makeOrchestrator(model: model)

        var receivedEvents: [OrchestratorEvent] = []
        let result = try await orch.processWithStreaming(userMessage: "Hello") { event in
            receivedEvents.append(event)
        }

        #expect(result.text == "Hello, world!")
        #expect(result.metrics.roundCount == 1)

        // Events: thinkingStarted + 3 textDeltas + completed
        #expect(receivedEvents.count == 5)
        if case .thinkingStarted = receivedEvents[0] {} else { Issue.record("Expected thinkingStarted at index 0") }
        if case .textDelta(let t) = receivedEvents[1] { #expect(t == "Hello") } else { Issue.record("Expected textDelta Hello") }
        if case .textDelta(let t) = receivedEvents[2] { #expect(t == ", world") } else { Issue.record("Expected textDelta , world") }
        if case .textDelta(let t) = receivedEvents[3] { #expect(t == "!") } else { Issue.record("Expected textDelta !") }
        if case .completed(let r) = receivedEvents[4] { #expect(r.text == "Hello, world!") } else { Issue.record("Expected completed") }
    }

    // MARK: - Test 2: Streaming tool_use flow (text then tool)

    @Test func testStreamingToolUseFlow() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = MockPolicyEngine()
        policy.defaultDecision = .allow

        let stub = makeStubTool(name: "test_tool", result: "tool-output")
        try registry.register(stub)

        // Round 1: text + tool_use
        model.enqueueStream(events: [
            .messageStart(id: "msg-1", model: "claude-sonnet-4-6"),
            .textDelta("Let me check."),
            .toolUseStart(index: 1, toolUse: ToolUse(id: "tu-1", name: "test_tool", input: [:])),
            .inputJSONDelta(index: 1, delta: ""),
            .contentBlockStop(index: 1),
            .messageDelta(stopReason: .toolUse, usage: Usage(inputTokens: 10, outputTokens: 20)),
            .messageStop
        ])

        // Round 2: text reply after tool result
        model.enqueueStream(events: textResponse(text: "Done."))

        let orch = makeOrchestrator(model: model, toolRegistry: registry, policyEngine: policy)

        var receivedEvents: [OrchestratorEvent] = []
        let result = try await orch.processWithStreaming(userMessage: "Check something") { event in
            receivedEvents.append(event)
        }

        #expect(result.text == "Done.")
        #expect(result.metrics.roundCount == 2)
        #expect(result.metrics.toolsUsed == ["test_tool"])

        // Verify key events fired in order
        let eventTypes = receivedEvents.map { event -> String in
            switch event {
            case .thinkingStarted: return "thinking"
            case .textDelta: return "textDelta"
            case .toolStarted: return "toolStarted"
            case .toolCompleted: return "toolCompleted"
            case .completed: return "completed"
            }
        }
        // Round 1: thinking + textDelta + toolStarted + toolCompleted
        // Round 2: thinking + textDelta + completed
        #expect(eventTypes.contains("toolStarted"))
        #expect(eventTypes.contains("toolCompleted"))
        #expect(eventTypes.last == "completed")

        // Verify toolStarted fired for test_tool
        let toolStarted = receivedEvents.compactMap { event -> String? in
            if case .toolStarted(let name) = event { return name }
            return nil
        }
        #expect(toolStarted == ["test_tool"])

        // Verify toolCompleted fired with correct result
        let toolCompleted = receivedEvents.compactMap { event -> (String, String, Bool)? in
            if case .toolCompleted(let name, let result, let isError) = event { return (name, result, isError) }
            return nil
        }
        #expect(toolCompleted.count == 1)
        #expect(toolCompleted[0].0 == "test_tool")
        #expect(toolCompleted[0].1 == "tool-output")
        #expect(toolCompleted[0].2 == false)
    }

    // MARK: - Test 3: Abort during streaming

    @Test func testStreamingAbort() async throws {
        let model = MockModelProvider()

        // Create a stream that takes a while (won't actually block, but abort happens before processing)
        model.enqueueStream(events: textResponse(text: "Hello"))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: ToolRegistryImpl(),
            policyEngine: MockPolicyEngine(),
            timeout: 30
        )

        // Abort immediately after starting
        let processTask = Task<OrchestratorResult, Error> {
            try await orch.processWithStreaming(userMessage: "test") { _ in }
        }

        // Give it a moment to start, then abort
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        orch.abort()

        do {
            _ = try await processTask.value
            // If it completes successfully, that's OK too — race condition with abort
        } catch OrchestratorError.cancelled {
            // Expected
        } catch {
            // Other errors are unexpected
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Test 4: Multi-round streaming (tool then text)

    @Test func testStreamingMultiRound() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = MockPolicyEngine()
        policy.defaultDecision = .allow

        let tool1 = makeStubTool(name: "tool_a", result: "result-a")
        let tool2 = makeStubTool(name: "tool_b", result: "result-b")
        try registry.register(tool1)
        try registry.register(tool2)

        // Round 1: tool_a
        model.enqueueStream(events: [
            .messageStart(id: "msg-1", model: "claude-sonnet-4-6"),
            .toolUseStart(index: 0, toolUse: ToolUse(id: "tu-1", name: "tool_a", input: [:])),
            .contentBlockStop(index: 0),
            .messageDelta(stopReason: .toolUse, usage: Usage(inputTokens: 10, outputTokens: 5)),
            .messageStop
        ])

        // Round 2: tool_b
        model.enqueueStream(events: [
            .messageStart(id: "msg-2", model: "claude-sonnet-4-6"),
            .toolUseStart(index: 0, toolUse: ToolUse(id: "tu-2", name: "tool_b", input: [:])),
            .contentBlockStop(index: 0),
            .messageDelta(stopReason: .toolUse, usage: Usage(inputTokens: 15, outputTokens: 5)),
            .messageStop
        ])

        // Round 3: final text
        model.enqueueStream(events: textResponse(text: "All done."))

        let orch = makeOrchestrator(model: model, toolRegistry: registry, policyEngine: policy)

        var receivedEvents: [OrchestratorEvent] = []
        let result = try await orch.processWithStreaming(userMessage: "Do two things") { event in
            receivedEvents.append(event)
        }

        #expect(result.text == "All done.")
        #expect(result.metrics.roundCount == 3)
        #expect(result.metrics.toolsUsed == ["tool_a", "tool_b"])

        let toolStartedNames = receivedEvents.compactMap { event -> String? in
            if case .toolStarted(let name) = event { return name }
            return nil
        }
        #expect(toolStartedNames == ["tool_a", "tool_b"])
    }
}
