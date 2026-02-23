import AppKit
import SwiftUI

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
