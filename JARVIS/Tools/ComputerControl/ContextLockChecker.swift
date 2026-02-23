import Foundation

// MARK: - ContextLockChecker

/// Shared context lock verification logic used by all input tools.
/// Checks that the orchestrator's current context lock matches the frontmost app.
/// Returns nil on success, or a human-readable error string on failure.
struct ContextLockChecker: Sendable {

    /// Returns the current context lock (set by get_ui_state), or nil if not set.
    let lockProvider: @Sendable () -> ContextLock?

    /// Returns the frontmost app's bundle ID and PID, or nil if unavailable.
    let appProvider: @Sendable () -> (bundleId: String, pid: Int32)?

    /// Returns nil if the context lock is valid for the frontmost app.
    /// Returns a descriptive error string if the check fails.
    func verify() -> String? {
        guard let lock = lockProvider() else {
            return "No context lock set. Call get_ui_state first to establish context."
        }
        guard let app = appProvider() else {
            return "No frontmost application detected."
        }
        guard app.bundleId == lock.bundleId else {
            return "Frontmost app changed from '\(lock.bundleId)' to '\(app.bundleId)'. Call get_ui_state to re-establish context."
        }
        guard app.pid == lock.pid else {
            return "Frontmost app PID changed. Call get_ui_state to re-establish context."
        }
        return nil
    }
}
