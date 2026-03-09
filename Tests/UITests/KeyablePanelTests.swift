import Testing
import AppKit
@testable import JARVIS

@Suite("KeyablePanel Tests")
struct KeyablePanelTests {

    @Test("canBecomeKey returns true")
    @MainActor
    func canBecomeKeyIsTrue() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        #expect(panel.canBecomeKey == true)
    }

    @Test("canBecomeMain returns true")
    @MainActor
    func canBecomeMainIsTrue() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        #expect(panel.canBecomeMain == true)
    }
}
