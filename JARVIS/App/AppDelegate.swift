import AppKit
import SwiftUI
import ApplicationServices
import CoreGraphics
import AVFoundation
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var viewModel: ChatViewModel?
    private var wakeWordDetector: WakeWordDetectorImpl?
    private var wakeWordEnabledObserver: NSObjectProtocol?
    private var lastKnownWakeWordEnabled: Bool = false

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

        // Wire the global keyboard shortcut (configured in General settings)
        KeyboardShortcuts.onKeyUp(for: .toggleJARVIS) { [weak self] in
            self?.togglePanel()
        }

        // Start wake word detection if enabled and access key is available.
        lastKnownWakeWordEnabled = UserDefaults.standard.bool(forKey: "wakeWordEnabled")
        Task {
            await startWakeWordDetectionIfEnabled()
        }

        // Observe UserDefaults changes so the toggle works at runtime.
        wakeWordEnabledObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let enabled = UserDefaults.standard.bool(forKey: "wakeWordEnabled")
            guard enabled != self.lastKnownWakeWordEnabled else { return }
            self.lastKnownWakeWordEnabled = enabled
            Task { @MainActor in
                if enabled {
                    Logger.app.info("Wake word toggled ON — starting detection")
                    await self.startWakeWordDetectionIfEnabled()
                } else {
                    Logger.app.info("Wake word toggled OFF — stopping detection")
                    await self.stopWakeWordDetection()
                }
            }
        }
    }

    // MARK: - Wake Word

    private func startWakeWordDetectionIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: "wakeWordEnabled") else {
            Logger.app.info("Wake word detection disabled — skipping")
            return
        }
        let keychain = KeychainHelper()
        guard let keyData = try? keychain.read(key: "picovoice_access_key"),
              let accessKey = String(data: keyData, encoding: .utf8),
              !accessKey.isEmpty else {
            Logger.app.warning("Wake word enabled but Picovoice access key not set — skipping")
            return
        }
        do {
            let engine = try PorcupineEngine(accessKey: accessKey)
            let audioInput = AVAudioEngineInput()
            let permChecker = SystemMicrophonePermission()
            let detector = WakeWordDetectorImpl(
                engine: engine,
                audioInput: audioInput,
                permissionChecker: permChecker
            )
            detector.onWakeWordDetected = { [weak self] in
                Logger.app.info("🎤 Wake word detected — activating JARVIS")
                NSSound(named: "Tink")?.play()
                self?.panel?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                // Placeholder: future milestone will trigger STT here
            }
            detector.onError = { error in
                Logger.app.error("Wake word detection error: \(error)")
            }
            try await detector.start()
            self.wakeWordDetector = detector
            Logger.app.info("Wake word detection active")
        } catch {
            Logger.app.error("Failed to start wake word detection: \(error)")
        }
    }

    private func stopWakeWordDetection() async {
        await wakeWordDetector?.stop()
        wakeWordDetector = nil
        Logger.app.info("Wake word detection stopped")
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

        // Microphone — required for wake word detection.
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            Task {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
                Logger.app.info("Requested Microphone permission")
            }
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
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
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

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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
