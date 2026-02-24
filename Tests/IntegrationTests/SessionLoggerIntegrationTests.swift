import Testing
import Foundation
@testable import JARVIS

@Suite("SessionLogger Integration Tests")
struct SessionLoggerIntegrationTests {

    // MARK: - 1. Simple query logs user message + assistant text + metrics

    @Test func testSimpleQueryLogsCorrectEvents() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(SystemInfoTool())
        let policy = PolicyEngineImpl()
        let logger = MockSessionLogger()

        model.enqueue(response: Response(
            id: "resp-1",
            model: "claude-sonnet-4-6",
            content: [.text("Hello, I can help with that.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 20, outputTokens: 10)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy,
            sessionLogger: logger
        )

        _ = try await orch.process(userMessage: "Hello")

        let events = logger.events
        #expect(events.first == .userMessage("Hello"))
        #expect(events.contains(.assistantText("Hello, I can help with that.")))
        #expect(events.last == .metrics(1, [], 0))
    }

    // MARK: - 2. Tool call logs toolCall + toolResult events in correct order

    @Test func testToolCallLogsCallAndResultInOrder() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(SystemInfoTool())
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let logger = MockSessionLogger()

        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "system_info", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 30, outputTokens: 10)
        ))
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.text("You're on macOS.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 60, outputTokens: 8)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy,
            sessionLogger: logger
        )

        _ = try await orch.process(userMessage: "What OS?")

        let events = logger.events

        let callIdx = events.firstIndex {
            if case .toolCall("system_info", _, _, .allow) = $0 { return true }
            return false
        }
        let resultIdx = events.firstIndex {
            if case .toolResult("system_info", false) = $0 { return true }
            return false
        }
        #expect(callIdx != nil)
        #expect(resultIdx != nil)
        #expect((callIdx ?? 999) < (resultIdx ?? 0))
        #expect(events.last == .metrics(2, ["system_info"], 0))
    }

    // MARK: - 3. Destructive tool with no confirmation handler logs toolRejected + error in metrics

    @Test func testDestructiveToolWithNoHandlerLogsRejected() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        // destructive risk → requireConfirmation by policy; no handler → auto-rejected
        try registry.register(makeStubTool(name: "dangerous_op", riskLevel: .destructive, result: "done"))
        let policy = PolicyEngineImpl(autonomyLevel: .smartDefault)
        let logger = MockSessionLogger()

        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-d", name: "dangerous_op", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 25, outputTokens: 8)
        ))
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.text("I couldn't perform that action.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 50, outputTokens: 10)
        ))

        // No confirmationHandler — auto-denies dangerous actions
        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy,
            sessionLogger: logger
        )

        _ = try await orch.process(userMessage: "Do the dangerous thing")

        let events = logger.events
        #expect(events.contains(.toolRejected("dangerous_op")))
        #expect(events.last == .metrics(2, [], 1))
    }

    // MARK: - 4. Streaming loop logs user message + assistant text + metrics

    @Test func testStreamingLoopLogsCorrectEvents() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl()
        let logger = MockSessionLogger()

        model.enqueueStream(events: [
            .messageStart(id: "s1", model: "claude-sonnet-4-6"),
            .textDelta("Great"),
            .textDelta(" question!"),
            .messageDelta(stopReason: .endTurn, usage: Usage(inputTokens: 15, outputTokens: 5)),
            .messageStop
        ])

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy,
            sessionLogger: logger
        )

        _ = try await orch.processWithStreaming(userMessage: "Hi") { _ in }

        let events = logger.events
        #expect(events.first == .userMessage("Hi"))
        #expect(events.contains(.assistantText("Great question!")))
        #expect(events.last == .metrics(1, [], 0))
    }
}
