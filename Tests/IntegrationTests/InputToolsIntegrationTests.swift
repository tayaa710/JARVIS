import Testing
import Foundation
import CoreGraphics
@testable import JARVIS

@Suite("Input Tools Integration Tests")
struct InputToolsIntegrationTests {

    private func makeAXService() -> MockAccessibilityService {
        let service = MockAccessibilityService()
        service.setDefaultSnapshot()
        return service
    }

    // MARK: - 1. keyboard_shortcut after get_ui_state

    @Test("keyboard_shortcut after get_ui_state: context lock set and shortcut executed")
    func keyboardShortcutAfterGetUIState() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let axService = makeAXService()
        let cache = UIStateCache()
        let mockInput = MockInputService()

        let getUIStateTool = GetUIStateTool(accessibilityService: axService, cache: cache)
        try registry.register(getUIStateTool)
        try registry.register(AXActionTool(accessibilityService: axService, cache: cache))
        try registry.register(AXFindTool(accessibilityService: axService, cache: cache))

        let orch = OrchestratorImpl(modelProvider: model, toolRegistry: registry, policyEngine: policy)

        getUIStateTool.contextLockSetter = { [weak orch] lock in
            orch?.setContextLock(lock)
        }

        let lockChecker = ContextLockChecker(
            lockProvider: { orch.contextLock },
            appProvider: { (bundleId: "com.test.app", pid: 1234) }
        )
        try registerInputTools(in: registry, inputService: mockInput,
                               contextLockChecker: lockChecker, cache: cache)

        // Round 1: Claude calls get_ui_state
        model.enqueue(response: Response(
            id: "r1", model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "get_ui_state", input: [:]))],
            stopReason: .toolUse, usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: Claude calls keyboard_shortcut cmd+c
        model.enqueue(response: Response(
            id: "r2", model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-2", name: "keyboard_shortcut",
                                       input: ["shortcut": .string("cmd+c")]))],
            stopReason: .toolUse, usage: Usage(inputTokens: 40, outputTokens: 8)
        ))

        // Round 3: Final text
        model.enqueue(response: Response(
            id: "r3", model: "claude-sonnet-4-6",
            content: [.text("Copied to clipboard.")],
            stopReason: .endTurn, usage: Usage(inputTokens: 60, outputTokens: 8)
        ))

        let result = try await orch.process(userMessage: "Copy selected text")

        #expect(result.text == "Copied to clipboard.")
        // Context lock set by get_ui_state
        #expect(orch.contextLock?.bundleId == "com.test.app")
        // Shortcut executed via MockInputService
        #expect(mockInput.pressedShortcuts.count == 1)
        #expect(mockInput.pressedShortcuts[0].modifiers == .maskCommand)
        #expect(mockInput.pressedShortcuts[0].keyCode == 8) // c
        // Cache invalidated by keyboard_shortcut
        #expect(cache.get() == nil)
    }

    // MARK: - 2. keyboard_type flow

    @Test("keyboard_type flow: get_ui_state then keyboard_type")
    func keyboardTypeFlow() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let axService = makeAXService()
        let cache = UIStateCache()
        let mockInput = MockInputService()

        let getUIStateTool = GetUIStateTool(accessibilityService: axService, cache: cache)
        try registry.register(getUIStateTool)
        try registry.register(AXActionTool(accessibilityService: axService, cache: cache))
        try registry.register(AXFindTool(accessibilityService: axService, cache: cache))

        let orch = OrchestratorImpl(modelProvider: model, toolRegistry: registry, policyEngine: policy)

        getUIStateTool.contextLockSetter = { [weak orch] lock in
            orch?.setContextLock(lock)
        }

        let lockChecker = ContextLockChecker(
            lockProvider: { orch.contextLock },
            appProvider: { (bundleId: "com.test.app", pid: 1234) }
        )
        try registerInputTools(in: registry, inputService: mockInput,
                               contextLockChecker: lockChecker, cache: cache)

        // Round 1: get_ui_state
        model.enqueue(response: Response(
            id: "r1", model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "get_ui_state", input: [:]))],
            stopReason: .toolUse, usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: keyboard_type
        model.enqueue(response: Response(
            id: "r2", model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-2", name: "keyboard_type",
                                       input: ["text": .string("Hello World")]))],
            stopReason: .toolUse, usage: Usage(inputTokens: 40, outputTokens: 8)
        ))

        // Round 3: Final
        model.enqueue(response: Response(
            id: "r3", model: "claude-sonnet-4-6",
            content: [.text("Typed the text.")],
            stopReason: .endTurn, usage: Usage(inputTokens: 60, outputTokens: 8)
        ))

        let result = try await orch.process(userMessage: "Type hello world")

        #expect(result.text == "Typed the text.")
        #expect(mockInput.typedTexts == ["Hello World"])
    }

    // MARK: - 3. context lock refused

    @Test("context lock refused: keyboard_type without get_ui_state fails")
    func contextLockRefused() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let cache = UIStateCache()
        let mockInput = MockInputService()

        let orch = OrchestratorImpl(modelProvider: model, toolRegistry: registry, policyEngine: policy)

        // lockProvider returns nil — no get_ui_state was called, so contextLock is nil
        let lockChecker = ContextLockChecker(
            lockProvider: { orch.contextLock },
            appProvider: { (bundleId: "com.test.app", pid: 1234) }
        )
        try registerInputTools(in: registry, inputService: mockInput,
                               contextLockChecker: lockChecker, cache: cache)

        // Round 1: Claude immediately calls keyboard_type (no prior get_ui_state)
        model.enqueue(response: Response(
            id: "r1", model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-1", name: "keyboard_type",
                                       input: ["text": .string("should fail")]))],
            stopReason: .toolUse, usage: Usage(inputTokens: 20, outputTokens: 8)
        ))

        // Round 2: Claude sees the error and stops
        model.enqueue(response: Response(
            id: "r2", model: "claude-sonnet-4-6",
            content: [.text("Could not type, no context lock.")],
            stopReason: .endTurn, usage: Usage(inputTokens: 40, outputTokens: 8)
        ))

        let result = try await orch.process(userMessage: "Type without getting UI state")

        #expect(result.text == "Could not type, no context lock.")
        // Typing must NOT have happened
        #expect(mockInput.typedTexts.isEmpty)
    }
}
