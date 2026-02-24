import ServiceManagement

// MARK: - Protocol

public protocol LaunchAtLoginManaging: AnyObject {
    var isEnabled: Bool { get set }
}

// MARK: - Implementation

/// Wraps SMAppService.mainApp to manage launch-at-login registration.
/// On unsigned/debug builds, register() may throw — this is expected.
/// Full functionality requires a signed distribution build.
public final class LaunchAtLoginManager: LaunchAtLoginManaging {

    public init() {}

    public var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    Logger.settings.info("Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    Logger.settings.info("Launch at login disabled")
                }
            } catch {
                Logger.settings.error("Failed to change launch at login: \(error)")
            }
        }
    }
}
