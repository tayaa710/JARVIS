import CoreGraphics

// MARK: - InputControlling

/// Abstracts CGEvent-based input generation. Enables mock injection for tests.
/// Production implementation: CGEventInputService.
/// Test implementation: MockInputService.
protocol InputControlling: Sendable {
    func typeText(_ text: String) async throws
    func pressShortcut(modifiers: CGEventFlags, keyCode: CGKeyCode) async throws
    func mouseClick(position: CGPoint, button: CGMouseButton, clickCount: Int) async throws
    func mouseMove(to position: CGPoint) async throws
}
