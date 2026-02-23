import CoreGraphics
import Foundation

// MARK: - CGEventInputService

/// Production InputControlling implementation using CGEvent.
/// Posts real keyboard and mouse events to the HID event system.
/// Requires Accessibility permission (same as AX tools).
/// Not unit-tested — CGEvent posting requires the real event system.
final class CGEventInputService: InputControlling, @unchecked Sendable {

    // MARK: - InputControlling

    /// Types each character as a Unicode keyDown/keyUp pair.
    /// A 5ms inter-character delay prevents dropped events on slower Macs.
    func typeText(_ text: String) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            let chars = String(scalar)
            var utf16 = Array(chars.utf16)

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else { continue }
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down.post(tap: .cgAnnotatedSessionEventTap)

            guard let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { continue }
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up.post(tap: .cgAnnotatedSessionEventTap)

            try await Task.sleep(nanoseconds: 5_000_000) // 5ms inter-character delay
        }
        Logger.input.info("typeText: typed \(text.count) character(s)")
    }

    /// Presses a virtual key with modifier flags (keyDown then keyUp).
    func pressShortcut(modifiers: CGEventFlags, keyCode: CGKeyCode) async throws {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = modifiers
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.flags = modifiers
        up.post(tap: .cgAnnotatedSessionEventTap)

        Logger.input.info("pressShortcut: keyCode=\(keyCode) modifiers=\(modifiers.rawValue)")
    }

    /// Posts mouseDown then mouseUp at the given position.
    func mouseClick(position: CGPoint, button: CGMouseButton, clickCount: Int) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType   = button == .right ? .rightMouseUp   : .leftMouseUp

        guard let down = CGEvent(mouseEventSource: source, mouseType: downType,
                                 mouseCursorPosition: position, mouseButton: button),
              let up = CGEvent(mouseEventSource: source, mouseType: upType,
                               mouseCursorPosition: position, mouseButton: button) else {
            return
        }
        down.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        up.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)

        Logger.input.info("mouseClick: \(button.rawValue == CGMouseButton.right.rawValue ? "right" : "left") ×\(clickCount) at (\(Int(position.x)), \(Int(position.y)))")
    }

    /// Posts a mouseMoved event at the given position.
    func mouseMove(to position: CGPoint) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                  mouseCursorPosition: position, mouseButton: .left) else {
            return
        }
        event.post(tap: .cgAnnotatedSessionEventTap)
        Logger.input.info("mouseMove: (\(Int(position.x)), \(Int(position.y)))")
    }
}
