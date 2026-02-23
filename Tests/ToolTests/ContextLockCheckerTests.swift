import Testing
import Foundation
@testable import JARVIS

@Suite("ContextLockChecker Tests")
struct ContextLockCheckerTests {

    @Test("Returns nil when lock matches frontmost app")
    func returnsNilWhenMatching() {
        let lock = ContextLock(bundleId: "com.example.app", pid: 1234)
        let checker = ContextLockChecker(
            lockProvider: { lock },
            appProvider: { (bundleId: "com.example.app", pid: 1234) }
        )
        #expect(checker.verify() == nil)
    }

    @Test("Returns error when no context lock set")
    func returnsErrorWhenNoLock() {
        let checker = ContextLockChecker(
            lockProvider: { nil },
            appProvider: { (bundleId: "com.example.app", pid: 1234) }
        )
        #expect(checker.verify() != nil)
    }

    @Test("Returns error when frontmost app is nil")
    func returnsErrorWhenNoApp() {
        let lock = ContextLock(bundleId: "com.example.app", pid: 1234)
        let checker = ContextLockChecker(
            lockProvider: { lock },
            appProvider: { nil }
        )
        #expect(checker.verify() != nil)
    }

    @Test("Returns error when bundleId mismatch")
    func returnsErrorWhenBundleIdMismatch() {
        let lock = ContextLock(bundleId: "com.example.app", pid: 1234)
        let checker = ContextLockChecker(
            lockProvider: { lock },
            appProvider: { (bundleId: "com.other.app", pid: 1234) }
        )
        #expect(checker.verify() != nil)
    }

    @Test("Returns error when PID mismatch")
    func returnsErrorWhenPIDMismatch() {
        let lock = ContextLock(bundleId: "com.example.app", pid: 1234)
        let checker = ContextLockChecker(
            lockProvider: { lock },
            appProvider: { (bundleId: "com.example.app", pid: 9999) }
        )
        #expect(checker.verify() != nil)
    }
}
