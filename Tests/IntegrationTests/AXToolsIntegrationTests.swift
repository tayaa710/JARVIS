import Testing
import Foundation
@testable import JARVIS

@Suite("AX Tools Integration Tests")
struct AXToolsIntegrationTests {

    // MARK: - Helpers

    private func makeAXService() -> MockAccessibilityService {
        let service = MockAccessibilityService()
        service.setDefaultSnapshot()
        return service
    }

    // MARK: - 1. get_ui_state then ax_action

    @Test("get_ui_state then ax_action: full loop with context lock set")
    func getUIStateThenAxAction() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let axService = makeAXService()
        let cache = UIStateCache()

        var capturedLock: ContextLock?
        let getUIStateTool = GetUIStateTool(accessibilityService: axService, cache: cache)
        getUIStateTool.contextLockSetter = { lock in capturedLock = lock }

        try registry.register(getUIStateTool)
        try registry.register(AXActionTool(accessibilityService: axService, cache: cache))
        try registry.register(AXFindTool(accessibilityService: axService, cache: cache))

        // Round 1: Claude calls get_ui_state
        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "get_ui_state", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: Claude calls ax_action press on @e2
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu-2",
                name: "ax_action",
                input: ["ref": .string("@e2"), "action": .string("press")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 40, outputTokens: 8)
        ))

        // Round 3: Final text
        model.enqueue(response: Response(
            id: "r3",
            model: "claude-sonnet-4-6",
            content: [.text("I pressed the OK button.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 60, outputTokens: 10)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "Press the OK button")

        #expect(result.text == "I pressed the OK button.")
        #expect(result.metrics.roundCount == 3)
        #expect(result.metrics.toolsUsed.contains("get_ui_state"))
        #expect(result.metrics.toolsUsed.contains("ax_action"))

        // Context lock should have been set by get_ui_state
        #expect(capturedLock?.bundleId == "com.test.app")
        #expect(capturedLock?.pid == 1234)

        // Cache should be nil after ax_action invalidated it
        #expect(cache.get() == nil)

        // walkFrontmostApp called once (ax_action doesn't walk)
        #expect(axService.walkCallCount == 1)
    }

    // MARK: - 2. ax_find with results

    @Test("ax_find: finds elements matching role filter")
    func axFindWithResults() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let axService = makeAXService()
        let cache = UIStateCache()

        try registry.register(GetUIStateTool(accessibilityService: axService, cache: cache))
        try registry.register(AXActionTool(accessibilityService: axService, cache: cache))
        try registry.register(AXFindTool(accessibilityService: axService, cache: cache))

        // Round 1: Claude calls ax_find
        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu-1",
                name: "ax_find",
                input: ["role": .string("AXButton")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 6)
        ))

        // Round 2: Final text
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.text("Found the button.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 50, outputTokens: 8)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "Find all buttons")
        #expect(result.text == "Found the button.")
        #expect(result.metrics.toolsUsed.contains("ax_find"))

        // Verify ax_find walked the tree (cache was empty)
        #expect(axService.walkCallCount == 1)

        // The conversation history should contain a tool result with button refs
        let history = orch.conversationHistory
        let toolResultMessages = history.filter { $0.role == .user }
        // Should have at least one tool result message
        #expect(toolResultMessages.count >= 1)
    }

    // MARK: - 3. get_ui_state caching

    @Test("get_ui_state caching: second call within TTL uses cache")
    func getUIStateCaching() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let axService = makeAXService()
        let cache = UIStateCache(ttl: 60) // Long TTL

        let getUIStateTool = GetUIStateTool(accessibilityService: axService, cache: cache)
        try registry.register(getUIStateTool)
        try registry.register(AXActionTool(accessibilityService: axService, cache: cache))
        try registry.register(AXFindTool(accessibilityService: axService, cache: cache))

        // Round 1: first get_ui_state
        model.enqueue(response: Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "get_ui_state", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 6)
        ))

        // Round 2: second get_ui_state (should use cache)
        model.enqueue(response: Response(
            id: "r2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-2", name: "get_ui_state", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 40, outputTokens: 6)
        ))

        // Round 3: Final text
        model.enqueue(response: Response(
            id: "r3",
            model: "claude-sonnet-4-6",
            content: [.text("Got the UI state twice.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 60, outputTokens: 8)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        _ = try await orch.process(userMessage: "Call get_ui_state twice quickly")

        // walkFrontmostApp should have been called only once (second call used cache)
        #expect(axService.walkCallCount == 1)
    }
}
