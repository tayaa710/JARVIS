import Foundation
import CoreGraphics
@testable import JARVIS

/// Test double for InputControlling. Records all calls and optionally throws.
final class MockInputService: InputControlling, @unchecked Sendable {

    // MARK: - Recorded Calls

    var typedTexts: [String] = []
    var pressedShortcuts: [(modifiers: CGEventFlags, keyCode: CGKeyCode)] = []
    var clicks: [(position: CGPoint, button: CGMouseButton, clickCount: Int)] = []
    var moves: [CGPoint] = []

    // MARK: - Configuration

    /// When set, every method throws this error instead of recording the call.
    var shouldThrow: Error? = nil

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - InputControlling

    func typeText(_ text: String) async throws {
        if let error = shouldThrow { throw error }
        lock.withLock { typedTexts.append(text) }
    }

    func pressShortcut(modifiers: CGEventFlags, keyCode: CGKeyCode) async throws {
        if let error = shouldThrow { throw error }
        lock.withLock { pressedShortcuts.append((modifiers: modifiers, keyCode: keyCode)) }
    }

    func mouseClick(position: CGPoint, button: CGMouseButton, clickCount: Int) async throws {
        if let error = shouldThrow { throw error }
        lock.withLock { clicks.append((position: position, button: button, clickCount: clickCount)) }
    }

    func mouseMove(to position: CGPoint) async throws {
        if let error = shouldThrow { throw error }
        lock.withLock { moves.append(position) }
    }
}
