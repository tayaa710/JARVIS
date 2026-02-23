import Testing
import ApplicationServices
@testable import JARVIS

@Suite("AXActionTool Tests")
struct AXActionToolTests {

    // MARK: - Configurable mock for action tests

    final class ActionMockService: AccessibilityServiceProtocol, @unchecked Sendable {
        var performActionCalls: [(ref: String, action: String)] = []
        var setValueCalls: [(ref: String, attribute: String, value: String)] = []
        var setFocusedCalls: [String] = []
        var actionResult: Bool = true
        var actionError: Error? = nil
        private let lock = NSLock()

        func checkPermission() -> Bool { true }
        func requestPermission() {}

        func walkFrontmostApp(maxDepth: Int, maxElements: Int) async throws -> UITreeSnapshot {
            let root = UIElementSnapshot(ref: "@e1", role: "AXApplication", title: "App",
                                         value: nil, isEnabled: true, frame: .zero, children: [])
            return UITreeSnapshot(appName: "App", bundleId: "com.test", pid: 1,
                                  root: root, elementCount: 1, truncated: false)
        }

        func elementForRef(_ ref: String) -> AXUIElement? { nil }
        func invalidateRefMap() {}

        func performAction(ref: String, action: String) async throws -> Bool {
            lock.lock(); defer { lock.unlock() }
            if let err = actionError { throw err }
            performActionCalls.append((ref: ref, action: action))
            return actionResult
        }

        func setValue(ref: String, attribute: String, value: String) async throws -> Bool {
            lock.lock(); defer { lock.unlock() }
            if let err = actionError { throw err }
            setValueCalls.append((ref: ref, attribute: attribute, value: value))
            return actionResult
        }

        func setFocused(ref: String) async throws -> Bool {
            lock.lock(); defer { lock.unlock() }
            if let err = actionError { throw err }
            setFocusedCalls.append(ref)
            return actionResult
        }
    }

    // MARK: - Helpers

    private func makeTool(service: ActionMockService? = nil, cache: UIStateCache? = nil)
    -> (AXActionTool, ActionMockService, UIStateCache) {
        let svc = service ?? ActionMockService()
        let c = cache ?? UIStateCache()
        return (AXActionTool(accessibilityService: svc, cache: c), svc, c)
    }

    private func execute(_ tool: AXActionTool, args: [String: JSONValue]) async throws -> ToolResult {
        try await tool.execute(id: "test-id", arguments: args)
    }

    // MARK: - Tests

    @Test("press action calls performAction with AXPress")
    func pressCallsPerformAction() async throws {
        let (tool, service, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e1"),
            "action": .string("press")
        ])
        #expect(!result.isError)
        #expect(service.performActionCalls.count == 1)
        #expect(service.performActionCalls[0].action == "AXPress")
        #expect(service.performActionCalls[0].ref == "@e1")
    }

    @Test("set_value calls setValue with correct ref and value")
    func setValueCallsCorrectly() async throws {
        let (tool, service, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e2"),
            "action": .string("set_value"),
            "value": .string("hello")
        ])
        #expect(!result.isError)
        #expect(service.setValueCalls.count == 1)
        #expect(service.setValueCalls[0].ref == "@e2")
        #expect(service.setValueCalls[0].value == "hello")
    }

    @Test("set_value without value argument returns error")
    func setValueWithoutValueReturnsError() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e1"),
            "action": .string("set_value")
        ])
        #expect(result.isError)
        #expect(result.content.contains("value"))
    }

    @Test("focus calls setFocused")
    func focusCallsSetFocused() async throws {
        let (tool, service, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e3"),
            "action": .string("focus")
        ])
        #expect(!result.isError)
        #expect(service.setFocusedCalls == ["@e3"])
    }

    @Test("show_menu calls performAction with AXShowMenu")
    func showMenuCallsPerformAction() async throws {
        let (tool, service, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e1"),
            "action": .string("show_menu")
        ])
        #expect(!result.isError)
        #expect(service.performActionCalls[0].action == "AXShowMenu")
    }

    @Test("raise calls performAction with AXRaise")
    func raiseCallsPerformAction() async throws {
        let (tool, service, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e1"),
            "action": .string("raise")
        ])
        #expect(!result.isError)
        #expect(service.performActionCalls[0].action == "AXRaise")
    }

    @Test("Invalid ref returns error")
    func invalidRefReturnsError() async throws {
        let service = ActionMockService()
        service.actionError = AXServiceError.invalidElement
        let (tool, _, _) = makeTool(service: service)
        let result = try await execute(tool, args: [
            "ref": .string("@e999"),
            "action": .string("press")
        ])
        #expect(result.isError)
    }

    @Test("Invalid action name returns error")
    func invalidActionReturnsError() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: [
            "ref": .string("@e1"),
            "action": .string("teleport")
        ])
        #expect(result.isError)
        #expect(result.content.contains("teleport"))
    }

    @Test("Cache is invalidated after successful action")
    func cacheInvalidatedAfterSuccess() async throws {
        let cache = UIStateCache()
        let root = UIElementSnapshot(ref: "@e1", role: "AXApp", title: nil,
                                     value: nil, isEnabled: true, frame: .zero, children: [])
        let snap = UITreeSnapshot(appName: "A", bundleId: "b", pid: 1, root: root, elementCount: 1, truncated: false)
        cache.set(result: "cached", snapshot: snap)
        let (tool, _, _) = makeTool(cache: cache)
        _ = try await execute(tool, args: ["ref": .string("@e1"), "action": .string("press")])
        #expect(cache.get() == nil)
    }

    @Test("Cache is invalidated even after failed action")
    func cacheInvalidatedAfterFailure() async throws {
        let cache = UIStateCache()
        let root = UIElementSnapshot(ref: "@e1", role: "AXApp", title: nil,
                                     value: nil, isEnabled: true, frame: .zero, children: [])
        let snap = UITreeSnapshot(appName: "A", bundleId: "b", pid: 1, root: root, elementCount: 1, truncated: false)
        cache.set(result: "cached", snapshot: snap)
        let service = ActionMockService()
        service.actionError = AXServiceError.invalidElement
        let (tool, _, _) = makeTool(service: service, cache: cache)
        _ = try await execute(tool, args: ["ref": .string("@e999"), "action": .string("press")])
        #expect(cache.get() == nil)
    }

    @Test("Risk level is caution")
    func riskLevelIsCaution() {
        let (tool, _, _) = makeTool()
        #expect(tool.riskLevel == .caution)
    }

    @Test("Tool name is ax_action")
    func toolName() {
        let (tool, _, _) = makeTool()
        #expect(tool.definition.name == "ax_action")
    }
}
