import ApplicationServices

// MARK: - Accessibility Service Protocol

/// The public interface for the accessibility service.
/// M010 tools depend on this protocol for UI state reading and element interaction.
protocol AccessibilityServiceProtocol: Sendable {

    /// Returns true if the process has Accessibility permission.
    func checkPermission() -> Bool

    /// Prompts the user to grant Accessibility permission via System Settings.
    func requestPermission()

    /// Walks the frontmost application's AX tree and returns a snapshot.
    /// - Parameters:
    ///   - maxDepth: Maximum depth to traverse. Default: 5.
    ///   - maxElements: Maximum number of elements to capture. Default: 300.
    /// - Throws: `AXServiceError.noFrontmostApp` if no app is frontmost.
    func walkFrontmostApp(maxDepth: Int, maxElements: Int) async throws -> UITreeSnapshot

    /// Returns the AXUIElement corresponding to a ref string (e.g. "@e1").
    /// The ref map is populated by the most recent `walkFrontmostApp` call.
    /// Returns nil if the ref is unknown or the map has been invalidated.
    func elementForRef(_ ref: String) -> AXUIElement?

    /// Clears the ref map. Call after an action changes the UI to prevent stale refs.
    func invalidateRefMap()
}
