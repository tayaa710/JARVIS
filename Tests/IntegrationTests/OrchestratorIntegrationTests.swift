import Testing
import Foundation
@testable import JARVIS

@Suite("Orchestrator Integration Tests")
struct OrchestratorIntegrationTests {

    // MARK: - 1. testSimpleQueryFixture
    // Simulates: user asks "What time is it?", Claude responds with text only.
    // Uses real ToolRegistryImpl, real PolicyEngineImpl, MockModelProvider.

    @Test func testSimpleQueryFixture() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(SystemInfoTool())
        let policy = PolicyEngineImpl()

        model.enqueue(response: Response(
            id: "resp-simple-1",
            model: "claude-sonnet-4-6",
            content: [.text("I don't have a real-time clock, but based on your system I can help.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 25, outputTokens: 18)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "What time is it?")

        #expect(result.text == "I don't have a real-time clock, but based on your system I can help.")
        #expect(result.metrics.roundCount == 1)
        #expect(result.metrics.toolsUsed.isEmpty)
        #expect(result.metrics.inputTokens == 25)
        #expect(result.metrics.outputTokens == 18)

        // Conversation history: user message + assistant response
        let history = orch.conversationHistory
        #expect(history.count == 2)
        #expect(history[0].role == .user)
        #expect(history[1].role == .assistant)
    }

    // MARK: - 2. testSingleToolFixture
    // Simulates: user asks "What OS am I on?", Claude calls system_info, gets result, responds.
    // Uses real SystemInfoTool + real PolicyEngineImpl (smartDefault).

    @Test func testSingleToolFixture() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(SystemInfoTool())
        let policy = PolicyEngineImpl(autonomyLevel: .smartDefault)

        // Round 1: Claude calls system_info
        model.enqueue(response: Response(
            id: "resp-tool-1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-sys-1", name: "system_info", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 30, outputTokens: 10)
        ))

        // Round 2: Claude responds with text after seeing tool result
        model.enqueue(response: Response(
            id: "resp-tool-2",
            model: "claude-sonnet-4-6",
            content: [.text("You're running macOS. Here's your system info.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 80, outputTokens: 15)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "What OS am I on?")

        #expect(result.text == "You're running macOS. Here's your system info.")
        #expect(result.metrics.roundCount == 2)
        #expect(result.metrics.toolsUsed == ["system_info"])
        #expect(result.metrics.errorsEncountered == 0)
        #expect(result.metrics.inputTokens == 110) // 30 + 80
        #expect(result.metrics.outputTokens == 25)  // 10 + 15

        // Conversation: user + assistant (tool_use) + user (tool_result) + assistant (final)
        let history = orch.conversationHistory
        #expect(history.count == 4)
    }

    // MARK: - 3. testMultiToolFixture
    // Simulates: user asks complex question, Claude calls tool_a then tool_b then responds.
    // Uses real ToolRegistryImpl with 2 stub tools + real PolicyEngineImpl.

    @Test func testMultiToolFixture() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "tool_a", result: "Result from tool A"))
        try registry.register(makeStubTool(name: "tool_b", result: "Result from tool B"))
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)

        // Round 1: tool_a
        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-a", name: "tool_a", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: tool_b
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-b", name: "tool_b", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 40, outputTokens: 8)
        ))

        // Round 3: final text
        model.enqueue(response: Response(
            id: "r3",
            model: "claude-sonnet-4-6",
            content: [.text("Based on both tools: all done.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 60, outputTokens: 12)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "Do something that needs two tools")

        #expect(result.text == "Based on both tools: all done.")
        #expect(result.metrics.roundCount == 3)
        #expect(result.metrics.toolsUsed == ["tool_a", "tool_b"])
        #expect(result.metrics.errorsEncountered == 0)

        // history: user + assistant(tu-a) + user(result-a) + assistant(tu-b) + user(result-b) + assistant(text)
        let history = orch.conversationHistory
        #expect(history.count == 6)
    }
}
