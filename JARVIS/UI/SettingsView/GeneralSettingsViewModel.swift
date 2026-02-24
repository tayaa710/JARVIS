import AppKit
import SwiftUI

// MARK: - AppearanceMode

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// The NSAppearance.Name to apply, or nil for system default.
    public var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light:  return .aqua
        case .dark:   return .darkAqua
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
public final class GeneralSettingsViewModel {

    // MARK: Appearance

    public var appearanceMode: AppearanceMode {
        didSet {
            applyAppearance()
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            Logger.settings.info("Appearance changed to \(appearanceMode.rawValue)")
        }
    }

    // MARK: Launch at Login

    private let launchAtLoginManager: any LaunchAtLoginManaging

    public var launchAtLogin: Bool {
        get { launchAtLoginManager.isEnabled }
        set {
            launchAtLoginManager.isEnabled = newValue
            Logger.settings.info("Launch at login set to \(newValue)")
        }
    }

    // MARK: Init

    public init(launchAtLoginManager: any LaunchAtLoginManaging = LaunchAtLoginManager()) {
        self.launchAtLoginManager = launchAtLoginManager
        let stored = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: stored) ?? .system
    }

    // MARK: - Private

    private func applyAppearance() {
        if let name = appearanceMode.appearanceName {
            NSApp.appearance = NSAppearance(named: name)
        } else {
            NSApp.appearance = nil
        }
    }
}
