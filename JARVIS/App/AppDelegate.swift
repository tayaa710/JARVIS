import AppKit
import SwiftUI
import ApplicationServices
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var viewModel: ChatViewModel?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Build the shared ViewModel
        let vm = ChatViewModel()
        self.viewModel = vm

        // Build the floating NSPanel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = "JARVIS"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ChatView(viewModel: vm))
        panel.delegate = self
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // Build the menu bar icon
        setupStatusItem()

        // Request required permissions after a brief delay so the window is visible first.
        // Accessibility and Screen Recording show system prompts; Automation is triggered
        // automatically by macOS when AppleScript first sends events (NSAppleEventsUsageDescription).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestPermissions()
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        // Accessibility — required for get_ui_state, ax_action, ax_find, and all input tools.
        // If not trusted, this call opens System Settings → Privacy & Security → Accessibility.
        if !AXIsProcessTrusted() {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            Logger.app.info("Requested Accessibility permission")
        }

        // Screen Recording — required for the screenshot tool.
        // CGRequestScreenCaptureAccess() is a no-op if already granted.
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            Logger.app.info("Requested Screen Recording permission")
        }
    }

    // MARK: - Menu Bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "JARVIS") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "J"
            }
            button.toolTip = "JARVIS"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show JARVIS", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit JARVIS", action: #selector(quitApp), keyEquivalent: "q"))

        item.menu = menu
        self.statusItem = item
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            statusItem?.menu?.item(at: 0)?.title = "Show JARVIS"
        } else {
            panel.makeKeyAndOrderFront(nil)
            statusItem?.menu?.item(at: 0)?.title = "Hide JARVIS"
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Hide instead of close so the panel stays alive
        if let panel, notification.object as? NSPanel === panel {
            panel.orderOut(nil)
            statusItem?.menu?.item(at: 0)?.title = "Show JARVIS"
        }
    }
}
