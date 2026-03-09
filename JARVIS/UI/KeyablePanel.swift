import AppKit

/// NSPanel subclass that always accepts key and main window status.
/// Required because accessory-mode apps (.accessory activation policy) normally
/// produce non-activating panels, which prevents SwiftUI controls from receiving
/// keyboard input. Overriding canBecomeKey and canBecomeMain restores normal
/// interaction while keeping the floating, always-on-top behaviour.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
