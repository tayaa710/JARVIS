import Testing
import Foundation
import CoreGraphics
@testable import JARVIS

@Suite("KeyboardShortcutTool Tests")
struct KeyboardShortcutToolTests {

    private func makeChecker(lockSet: Bool = true) -> ContextLockChecker {
        ContextLockChecker(
            lockProvider: { lockSet ? ContextLock(bundleId: "com.test.app", pid: 1234) : nil },
            appProvider: { (bundleId: "com.test.app", pid: 1234) }
        )
    }

    private func makeSnapshot() -> UITreeSnapshot {
        let root = UIElementSnapshot(ref: "@e1", role: "AXApp", title: nil, value: nil,
                                     isEnabled: true, frame: .zero, children: [])
        return UITreeSnapshot(appName: "Test", bundleId: "com.test", pid: 0,
                              root: root, elementCount: 1, truncated: false)
    }

    @Test("Risk level is caution")
    func riskLevel() {
        let tool = KeyboardShortcutTool(inputService: MockInputService(),
                                        contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        #expect(tool.riskLevel == .caution)
    }

    @Test("Definition has correct name")
    func definitionName() {
        let tool = KeyboardShortcutTool(inputService: MockInputService(),
                                        contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        #expect(tool.definition.name == "keyboard_shortcut")
    }

    @Test("Valid cmd+c shortcut succeeds")
    func cmdC() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("cmd+c")])
        #expect(!result.isError)
        #expect(mockInput.pressedShortcuts.count == 1)
        #expect(mockInput.pressedShortcuts[0].keyCode == 8) // c
        #expect(mockInput.pressedShortcuts[0].modifiers == .maskCommand)
    }

    @Test("Valid ctrl+shift+a with multiple modifiers succeeds")
    func ctrlShiftA() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("ctrl+shift+a")])
        #expect(!result.isError)
        #expect(mockInput.pressedShortcuts.count == 1)
        #expect(mockInput.pressedShortcuts[0].keyCode == 0) // a
        let expected = CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue)
        #expect(mockInput.pressedShortcuts[0].modifiers == expected)
    }

    @Test("Invalid key name returns clear error")
    func invalidKeyName() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("cmd+xyz")])
        #expect(result.isError)
        #expect(mockInput.pressedShortcuts.isEmpty)
    }

    @Test("Missing shortcut argument returns error")
    func missingShortcut() async throws {
        let tool = KeyboardShortcutTool(inputService: MockInputService(), contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
    }

    @Test("Empty shortcut string returns error")
    func emptyShortcut() async throws {
        let tool = KeyboardShortcutTool(inputService: MockInputService(), contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("")])
        #expect(result.isError)
    }

    @Test("Shortcut with only modifiers returns error")
    func onlyModifiers() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("cmd+shift")])
        #expect(result.isError)
        #expect(mockInput.pressedShortcuts.isEmpty)
    }

    @Test("Context lock check failure returns error and does not press shortcut")
    func contextLockFails() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(lockSet: false),
                                        cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["shortcut": .string("cmd+c")])
        #expect(result.isError)
        #expect(mockInput.pressedShortcuts.isEmpty)
    }

    @Test("Cache is invalidated after shortcut")
    func cacheInvalidated() async throws {
        let mockInput = MockInputService()
        let cache = UIStateCache(ttl: 60)
        cache.set(result: "test", snapshot: makeSnapshot())

        let tool = KeyboardShortcutTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                        cache: cache, postActionDelay: 0)
        _ = try await tool.execute(id: "t1", arguments: ["shortcut": .string("cmd+c")])
        #expect(cache.get() == nil)
    }
}
