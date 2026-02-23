import Testing
import CoreGraphics
@testable import JARVIS

@Suite("UIStateCache Tests")
struct UIStateCacheTests {

    // MARK: - Helpers

    private func makeSnapshot(appName: String = "TestApp") -> UITreeSnapshot {
        let root = UIElementSnapshot(ref: "@e1", role: "AXApplication", title: appName,
                                     value: nil, isEnabled: true, frame: .zero, children: [])
        return UITreeSnapshot(appName: appName, bundleId: "com.test", pid: 1,
                              root: root, elementCount: 1, truncated: false)
    }

    // MARK: - Tests

    @Test("Fresh cache returns nil")
    func freshCacheReturnsNil() {
        let cache = UIStateCache()
        #expect(cache.get() == nil)
    }

    @Test("After set, get returns cached value")
    func afterSetGetReturns() {
        let cache = UIStateCache()
        let snapshot = makeSnapshot()
        cache.set(result: "formatted", snapshot: snapshot)
        let cached = cache.get()
        #expect(cached?.result == "formatted")
        #expect(cached?.snapshot.appName == "TestApp")
    }

    @Test("After TTL expires, get returns nil")
    func afterTTLExpires() async throws {
        let cache = UIStateCache(ttl: 0.05)
        let snapshot = makeSnapshot()
        cache.set(result: "formatted", snapshot: snapshot)
        #expect(cache.get() != nil)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        #expect(cache.get() == nil)
    }

    @Test("After invalidate, get returns nil")
    func afterInvalidate() {
        let cache = UIStateCache()
        let snapshot = makeSnapshot()
        cache.set(result: "formatted", snapshot: snapshot)
        cache.invalidate()
        #expect(cache.get() == nil)
    }

    @Test("Set overwrites previous value")
    func setOverwrites() {
        let cache = UIStateCache()
        cache.set(result: "first", snapshot: makeSnapshot(appName: "App1"))
        cache.set(result: "second", snapshot: makeSnapshot(appName: "App2"))
        let cached = cache.get()
        #expect(cached?.result == "second")
        #expect(cached?.snapshot.appName == "App2")
    }

    @Test("Thread safety: concurrent get/set doesn't crash")
    func threadSafety() async {
        let cache = UIStateCache()
        let snapshot = makeSnapshot()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    if i % 2 == 0 {
                        cache.set(result: "result\(i)", snapshot: snapshot)
                    } else {
                        _ = cache.get()
                    }
                }
            }
        }
        // No crash = success
    }
}
