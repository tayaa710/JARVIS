import Testing
import CoreGraphics
@testable import JARVIS

@Suite("KeyCodeMap Tests")
struct KeyCodeMapTests {

    @Test("Letter a maps to virtual key 0")
    func letterA() {
        #expect(KeyCodeMap.virtualKey(for: "a") == 0)
    }

    @Test("Letter c maps to virtual key 8")
    func letterC() {
        #expect(KeyCodeMap.virtualKey(for: "c") == 8)
    }

    @Test("Letter z maps to virtual key 6")
    func letterZ() {
        #expect(KeyCodeMap.virtualKey(for: "z") == 6)
    }

    @Test("Number 0 maps to virtual key 29")
    func number0() {
        #expect(KeyCodeMap.virtualKey(for: "0") == 29)
    }

    @Test("Number 1 maps to virtual key 18")
    func number1() {
        #expect(KeyCodeMap.virtualKey(for: "1") == 18)
    }

    @Test("Special keys: return, tab, space, escape")
    func specialKeys() {
        #expect(KeyCodeMap.virtualKey(for: "return") == 36)
        #expect(KeyCodeMap.virtualKey(for: "tab") == 48)
        #expect(KeyCodeMap.virtualKey(for: "space") == 49)
        #expect(KeyCodeMap.virtualKey(for: "escape") == 53)
    }

    @Test("Arrow keys")
    func arrowKeys() {
        #expect(KeyCodeMap.virtualKey(for: "up") == 126)
        #expect(KeyCodeMap.virtualKey(for: "down") == 125)
        #expect(KeyCodeMap.virtualKey(for: "left") == 123)
        #expect(KeyCodeMap.virtualKey(for: "right") == 124)
    }

    @Test("F-keys: f1 and f12")
    func fKeys() {
        #expect(KeyCodeMap.virtualKey(for: "f1") == 122)
        #expect(KeyCodeMap.virtualKey(for: "f12") == 111)
    }

    @Test("Unknown key returns nil")
    func unknownKey() {
        #expect(KeyCodeMap.virtualKey(for: "xyz") == nil)
        #expect(KeyCodeMap.virtualKey(for: "superkey") == nil)
    }

    @Test("Modifier parsing")
    func modifierParsing() {
        #expect(KeyCodeMap.modifierFlags(for: "cmd") == .maskCommand)
        #expect(KeyCodeMap.modifierFlags(for: "command") == .maskCommand)
        #expect(KeyCodeMap.modifierFlags(for: "shift") == .maskShift)
        #expect(KeyCodeMap.modifierFlags(for: "ctrl") == .maskControl)
        #expect(KeyCodeMap.modifierFlags(for: "control") == .maskControl)
        #expect(KeyCodeMap.modifierFlags(for: "alt") == .maskAlternate)
        #expect(KeyCodeMap.modifierFlags(for: "option") == .maskAlternate)
    }

    @Test("Unknown modifier returns nil")
    func unknownModifier() {
        #expect(KeyCodeMap.modifierFlags(for: "win") == nil)
        #expect(KeyCodeMap.modifierFlags(for: "meta") == nil)
    }

    @Test("parseCombo cmd+c returns correct tuple")
    func parseComboCmdC() throws {
        let combo = try #require(KeyCodeMap.parseCombo("cmd+c"))
        #expect(combo.modifiers == .maskCommand)
        #expect(combo.keyCode == 8) // c = 8
    }

    @Test("parseCombo ctrl+shift+a returns combined modifiers")
    func parseComboCtrlShiftA() throws {
        let combo = try #require(KeyCodeMap.parseCombo("ctrl+shift+a"))
        let expected = CGEventFlags(rawValue: CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue)
        #expect(combo.modifiers == expected)
        #expect(combo.keyCode == 0) // a = 0
    }
}
