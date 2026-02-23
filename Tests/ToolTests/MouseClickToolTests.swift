import Testing
import Foundation
import CoreGraphics
@testable import JARVIS

@Suite("MouseClickTool Tests")
struct MouseClickToolTests {

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
        let tool = MouseClickTool(inputService: MockInputService(),
                                  contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        #expect(tool.riskLevel == .caution)
    }

    @Test("Valid click at coordinates succeeds")
    func validClick() async throws {
        let mockInput = MockInputService()
        let tool = MouseClickTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(200)])
        #expect(!result.isError)
        #expect(mockInput.clicks.count == 1)
        #expect(mockInput.clicks[0].position == CGPoint(x: 100, y: 200))
        #expect(mockInput.clicks[0].button.rawValue == CGMouseButton.left.rawValue)
        #expect(mockInput.clicks[0].clickCount == 1)
    }

    @Test("Double click with click_count 2")
    func doubleClick() async throws {
        let mockInput = MockInputService()
        let tool = MouseClickTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1",
            arguments: ["x": .number(50), "y": .number(75), "click_count": .number(2)])
        #expect(!result.isError)
        #expect(mockInput.clicks[0].clickCount == 2)
    }

    @Test("Right click with button right")
    func rightClick() async throws {
        let mockInput = MockInputService()
        let tool = MouseClickTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1",
            arguments: ["x": .number(50), "y": .number(75), "button": .string("right")])
        #expect(!result.isError)
        #expect(mockInput.clicks[0].button.rawValue == CGMouseButton.right.rawValue)
    }

    @Test("Missing x or y returns error")
    func missingCoordinates() async throws {
        let tool = MouseClickTool(inputService: MockInputService(), contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result1 = try await tool.execute(id: "t1", arguments: ["x": .number(100)])
        #expect(result1.isError)
        let result2 = try await tool.execute(id: "t2", arguments: ["y": .number(100)])
        #expect(result2.isError)
    }

    @Test("Invalid button value returns error")
    func invalidButton() async throws {
        let tool = MouseClickTool(inputService: MockInputService(), contextLockChecker: makeChecker(),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1",
            arguments: ["x": .number(100), "y": .number(100), "button": .string("middle")])
        #expect(result.isError)
    }

    @Test("Context lock check failure returns error")
    func contextLockFails() async throws {
        let mockInput = MockInputService()
        let tool = MouseClickTool(inputService: mockInput, contextLockChecker: makeChecker(lockSet: false),
                                  cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(100)])
        #expect(result.isError)
        #expect(mockInput.clicks.isEmpty)
    }

    @Test("Cache is invalidated after click")
    func cacheInvalidated() async throws {
        let mockInput = MockInputService()
        let cache = UIStateCache(ttl: 60)
        cache.set(result: "test", snapshot: makeSnapshot())

        let tool = MouseClickTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                  cache: cache, postActionDelay: 0)
        _ = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(100)])
        #expect(cache.get() == nil)
    }
}
