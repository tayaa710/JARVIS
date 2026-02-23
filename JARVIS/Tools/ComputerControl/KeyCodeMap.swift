import CoreGraphics

// MARK: - KeyCodeMap

/// Maps human-readable key names to macOS virtual key codes and CGEventFlags modifiers.
/// All lookups are case-insensitive (callers should pass lowercase).
enum KeyCodeMap {

    // MARK: - Virtual Key Lookup

    /// Returns the macOS virtual key code for a given key name (lowercase).
    /// Returns nil for unknown keys.
    static func virtualKey(for name: String) -> CGKeyCode? {
        return keyCodeTable[name]
    }

    // MARK: - Modifier Flag Lookup

    /// Returns the CGEventFlags for a given modifier name (lowercase).
    /// Returns nil for unknown modifiers.
    static func modifierFlags(for name: String) -> CGEventFlags? {
        return modifierTable[name]
    }

    // MARK: - Combo Parsing

    /// Parses a combo string like "cmd+c" or "ctrl+shift+a" into modifiers and key code.
    /// Returns nil if the combo is empty, contains unknown components, or has no key.
    static func parseCombo(_ combo: String) -> (modifiers: CGEventFlags, keyCode: CGKeyCode)? {
        let parts = combo.lowercased().components(separatedBy: "+")
        var modifiers = CGEventFlags()
        var keyCode: CGKeyCode? = nil

        for part in parts {
            if let flags = modifierFlags(for: part) {
                modifiers.insert(flags)
            } else if let code = virtualKey(for: part) {
                keyCode = code
            } else {
                return nil // Unknown component
            }
        }

        guard let key = keyCode else { return nil }
        return (modifiers: modifiers, keyCode: key)
    }

    // MARK: - Tables

    private static let keyCodeTable: [String: CGKeyCode] = [
        // Letters (US QWERTY layout virtual key codes)
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,
        "z": 6,  "x": 7,  "c": 8,  "v": 9,  "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31,
        "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,

        // Numbers
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
        "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,

        // Special keys
        "return": 36,
        "tab": 48,
        "space": 49,
        "delete": 51,
        "backspace": 51,
        "escape": 53,
        "esc": 53,

        // Arrow keys
        "left": 123,
        "right": 124,
        "down": 125,
        "up": 126,

        // Navigation
        "home": 115,
        "end": 119,
        "pageup": 116,
        "pagedown": 121,

        // Function keys
        "f1": 122,
        "f2": 120,
        "f3": 99,
        "f4": 118,
        "f5": 96,
        "f6": 97,
        "f7": 98,
        "f8": 100,
        "f9": 101,
        "f10": 109,
        "f11": 103,
        "f12": 111,
    ]

    private static let modifierTable: [String: CGEventFlags] = [
        "cmd":     .maskCommand,
        "command": .maskCommand,
        "shift":   .maskShift,
        "alt":     .maskAlternate,
        "option":  .maskAlternate,
        "ctrl":    .maskControl,
        "control": .maskControl,
    ]
}
