import Foundation

// MARK: - UIStateCache

/// A short-lived cache for the most recent UI state snapshot.
/// Shared between GetUIStateTool (reads/writes) and AXActionTool (invalidates).
/// Default TTL: 0.5 seconds.
final class UIStateCache: @unchecked Sendable {

    // MARK: - Private State

    private let lock = NSLock()
    private var cachedResult: String?
    private var cachedSnapshot: UITreeSnapshot?
    private var cacheTime: Date?
    private let ttl: TimeInterval

    // MARK: - Init

    init(ttl: TimeInterval = 0.5) {
        self.ttl = ttl
    }

    // MARK: - Public API

    /// Returns the cached (result, snapshot) pair if it exists and has not expired.
    func get() -> (result: String, snapshot: UITreeSnapshot)? {
        lock.lock()
        defer { lock.unlock() }
        guard let result = cachedResult,
              let snapshot = cachedSnapshot,
              let time = cacheTime,
              Date().timeIntervalSince(time) < ttl else {
            return nil
        }
        return (result: result, snapshot: snapshot)
    }

    /// Stores a new result and snapshot, resetting the TTL clock.
    func set(result: String, snapshot: UITreeSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        cachedResult = result
        cachedSnapshot = snapshot
        cacheTime = Date()
    }

    /// Clears the cache immediately (e.g. after an action changes the UI).
    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cachedResult = nil
        cachedSnapshot = nil
        cacheTime = nil
    }
}
