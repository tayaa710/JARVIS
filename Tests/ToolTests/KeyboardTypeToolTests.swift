import Testing
import Foundation
import CoreGraphics
@testable import JARVIS

@Suite("KeyboardTypeTool Tests")
struct KeyboardTypeToolTests {

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
        let tool = KeyboardTypeTool(inputService: MockInputService(),
                                    contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        #expect(tool.riskLevel == .caution)
    }

    @Test("Definition has correct name")
    func definitionName() {
        let tool = KeyboardTypeTool(inputService: MockInputService(),
                                    contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        #expect(tool.definition.name == "keyboard_type")
    }

    @Test("Valid text types successfully")
    func validTextTypes() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("hello")])
        #expect(!result.isError)
        #expect(mockInput.typedTexts == ["hello"])
    }

    @Test("Empty text returns error")
    func emptyTextError() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("")])
        #expect(result.isError)
        #expect(mockInput.typedTexts.isEmpty)
    }

    @Test("Missing text argument returns error")
    func missingTextError() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
        #expect(mockInput.typedTexts.isEmpty)
    }

    @Test("Context lock check failure returns error and does not type")
    func contextLockFails() async throws {
        let mockInput = MockInputService()
        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(lockSet: false),
                                    cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("hello")])
        #expect(result.isError)
        #expect(mockInput.typedTexts.isEmpty)
    }

    @Test("Cache is invalidated after typing")
    func cacheInvalidated() async throws {
        let mockInput = MockInputService()
        let cache = UIStateCache(ttl: 60)
        cache.set(result: "test", snapshot: makeSnapshot())

        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                    cache: cache, postActionDelay: 0)
        _ = try await tool.execute(id: "t1", arguments: ["text": .string("hello")])
        #expect(cache.get() == nil)
    }

    @Test("InputService error is returned as tool error")
    func inputServiceError() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test failure" }
        }
        let mockInput = MockInputService()
        mockInput.shouldThrow = TestError()
        let tool = KeyboardTypeTool(inputService: mockInput, contextLockChecker: makeChecker(),
                                    cache: UIStateCache(), postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("hello")])
        #expect(result.isError)
    }
}
