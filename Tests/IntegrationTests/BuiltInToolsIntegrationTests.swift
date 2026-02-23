import Testing
import Foundation
@testable import JARVIS

@Suite("Built-In Tools Integration Tests", .serialized)
struct BuiltInToolsIntegrationTests {

    // Register all 9 built-in tools in a fresh registry
    private func makeRegistry() throws -> ToolRegistryImpl {
        let registry = ToolRegistryImpl()
        try registry.register(AppListTool())
        try registry.register(AppOpenTool())
        try registry.register(FileSearchTool())
        try registry.register(FileReadTool())
        try registry.register(FileWriteTool())
        try registry.register(ClipboardReadTool())
        try registry.register(ClipboardWriteTool())
        try registry.register(WindowListTool())
        try registry.register(WindowManageTool())
        return registry
    }

    // MARK: - Test 1: Full loop with app_list
    // MockModelProvider: (1) tool_use for app_list, (2) text after seeing result

    @Test func fullLoopWithAppList() async throws {
        let model = MockModelProvider()
        let registry = try makeRegistry()
        let policy = PolicyEngineImpl(autonomyLevel: .smartDefault)

        // Round 1: Claude requests app_list
        model.enqueue(response: Response(
            id: "resp-al-1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-al-1", name: "app_list", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: Claude replies after seeing app list
        model.enqueue(response: Response(
            id: "resp-al-2",
            model: "claude-sonnet-4-6",
            content: [.text("Here are the running applications.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 60, outputTokens: 10)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "What apps are running?")

        #expect(result.text == "Here are the running applications.")
        #expect(result.metrics.roundCount == 2)
        #expect(result.metrics.toolsUsed == ["app_list"])
        #expect(result.metrics.errorsEncountered == 0)

        // history: user + assistant(tool_use) + user(tool_result) + assistant(text)
        let history = orch.conversationHistory
        #expect(history.count == 4)
        #expect(history[0].role == .user)
        #expect(history[1].role == .assistant)
        #expect(history[2].role == .user)
        #expect(history[3].role == .assistant)
    }

}
