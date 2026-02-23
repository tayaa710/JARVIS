import Foundation

// MARK: - ScreenshotCacheEntry

struct ScreenshotCacheEntry: Sendable {
    let data: Data
    let mediaType: String
    let width: Int
    let height: Int
    let timestamp: Date
}

// MARK: - ScreenshotCache

/// Thread-safe cache for screenshot data with configurable TTL (default 30s).
final class ScreenshotCache: @unchecked Sendable {

    private let ttl: TimeInterval
    private var entry: ScreenshotCacheEntry?
    private let lock = NSLock()

    init(ttl: TimeInterval = 30) {
        self.ttl = ttl
    }

    /// Store a new screenshot entry.
    func set(data: Data, mediaType: String, width: Int, height: Int) {
        lock.withLock {
            entry = ScreenshotCacheEntry(
                data: data,
                mediaType: mediaType,
                width: width,
                height: height,
                timestamp: Date()
            )
        }
    }

    /// Return the cached entry if it is within the TTL, otherwise nil.
    func get() -> ScreenshotCacheEntry? {
        lock.withLock {
            guard let e = entry else { return nil }
            guard Date().timeIntervalSince(e.timestamp) < ttl else {
                entry = nil
                return nil
            }
            return e
        }
    }

    /// Explicitly invalidate the cache.
    func invalidate() {
        lock.withLock { entry = nil }
    }
}
