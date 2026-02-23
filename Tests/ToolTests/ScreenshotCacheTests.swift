import Testing
import Foundation
@testable import JARVIS

@Suite("ScreenshotCache Tests")
struct ScreenshotCacheTests {

    private func makeData() -> Data { Data([0xFF, 0xD8, 0xFF]) }

    @Test("Store and retrieve within TTL returns data")
    func storeAndRetrieveWithinTTL() {
        let cache = ScreenshotCache(ttl: 60)
        let data = makeData()
        cache.set(data: data, mediaType: "image/jpeg", width: 100, height: 100)
        let entry = cache.get()
        #expect(entry != nil)
        #expect(entry?.data == data)
        #expect(entry?.mediaType == "image/jpeg")
        #expect(entry?.width == 100)
        #expect(entry?.height == 100)
    }

    @Test("Retrieve after TTL returns nil")
    func retrieveAfterTTLReturnsNil() async throws {
        let cache = ScreenshotCache(ttl: 0.05)
        cache.set(data: makeData(), mediaType: "image/jpeg", width: 100, height: 100)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        #expect(cache.get() == nil)
    }

    @Test("Invalidate clears cache")
    func invalidateClearsCache() {
        let cache = ScreenshotCache(ttl: 60)
        cache.set(data: makeData(), mediaType: "image/jpeg", width: 100, height: 100)
        cache.invalidate()
        #expect(cache.get() == nil)
    }

    @Test("Overwrite replaces previous entry")
    func overwriteReplacesPrevious() {
        let cache = ScreenshotCache(ttl: 60)
        let data1 = Data([0x01])
        let data2 = Data([0x02])
        cache.set(data: data1, mediaType: "image/jpeg", width: 50, height: 50)
        cache.set(data: data2, mediaType: "image/png", width: 200, height: 200)
        let entry = cache.get()
        #expect(entry?.data == data2)
        #expect(entry?.mediaType == "image/png")
        #expect(entry?.width == 200)
    }

    @Test("Concurrent access does not crash")
    func concurrentAccessDoesNotCrash() async {
        let cache = ScreenshotCache(ttl: 60)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    if i % 2 == 0 {
                        cache.set(data: Data([UInt8(i)]), mediaType: "image/jpeg",
                                  width: i * 10, height: i * 10)
                    } else {
                        _ = cache.get()
                    }
                }
            }
        }
    }

    @Test("Empty cache returns nil")
    func emptyCacheReturnsNil() {
        let cache = ScreenshotCache(ttl: 60)
        #expect(cache.get() == nil)
    }
}
