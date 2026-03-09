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
    private var wakeWordPausedForTTS: Bool = false

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        // Build the shared ViewModel
        let vm = ChatViewModel()
        self.viewModel = vm

        // Wire TTS ↔ wake word pause/resume
        vm.onTTSActiveChanged = { [weak self] isSpeaking in
            guard let self else { return }
            Task { @MainActor in
                if isSpeaking {
                    // Pause wake word while JARVIS speaks to prevent echo triggering
                    await self.wakeWordDetector?.pause()
                    self.wakeWordPausedForTTS = true
                    Logger.app.info("Wake word paused (TTS active)")
                } else if self.wakeWordPausedForTTS {
                    // Resume wake word after TTS finishes
                    try? await self.wakeWordDetector?.resume()
                    self.wakeWordPausedForTTS = false
                    Logger.app.info("Wake word resumed (TTS finished)")
                }
            }
        }

        // Build the floating panel — KeyablePanel ensures SwiftUI controls receive
        // keyboard input even under .accessory activation policy.
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        panel.title = "JARVIS"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: ChatView(viewModel: vm))
        panel.delegate = self
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
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

        // Resume wake word detection when status returns to idle after STT finishes.
        Task { @MainActor [weak self] in
            var lastWasListening = false
            while !Task.isCancelled {
                let isListening = vm.isListeningForSpeech
                if lastWasListening && !isListening {
                    // Transitioned from listening → not listening; resume wake word
                    Task {
                        try? await self?.wakeWordDetector?.resume()
                        Logger.app.info("Wake word detection resumed after STT")
                    }
                }
                lastWasListening = isListening
                try? await Task.sleep(nanoseconds: 200_000_000) // poll every 200ms
            }
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
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Stop any active TTS before starting STT
                    await self.viewModel?.stopSpeaking()
                    // Pause wake word detection while STT is active
                    await self.wakeWordDetector?.pause()
                    // Start speech input; wake word resumes after status returns to idle
                    await self.viewModel?.startListening()
                }
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
            button.image = arcReactorImage(dim: false)
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

    // MARK: - Arc Reactor Menu Bar Icon

    private func arcReactorImage(dim: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let centre = NSPoint(x: rect.midX, y: rect.midY)
            let outerR: CGFloat = 8
            let innerR: CGFloat = 4
            let alpha: CGFloat  = dim ? 0.35 : 0.85
            NSColor(calibratedRed: 0, green: 0.667, blue: 1, alpha: alpha).setStroke()
            // Outer ring
            let outer = NSBezierPath(ovalIn: NSRect(
                x: centre.x - outerR, y: centre.y - outerR,
                width: outerR * 2, height: outerR * 2
            ))
            outer.lineWidth = 1.5
            outer.stroke()
            // Inner ring
            let inner = NSBezierPath(ovalIn: NSRect(
                x: centre.x - innerR, y: centre.y - innerR,
                width: innerR * 2, height: innerR * 2
            ))
            inner.lineWidth = 1
            inner.stroke()
            // Centre dot
            NSColor(calibratedRed: 0, green: 0.667, blue: 1, alpha: alpha).setFill()
            let dot = NSBezierPath(ovalIn: NSRect(
                x: centre.x - 1.5, y: centre.y - 1.5,
                width: 3, height: 3
            ))
            dot.fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
            statusItem?.menu?.item(at: 0)?.title = "Show JARVIS"
        } else {
            NSApp.activate(ignoringOtherApps: true)
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
