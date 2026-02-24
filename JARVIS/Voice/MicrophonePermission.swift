import AVFoundation

// MARK: - MicPermissionStatus

public enum MicPermissionStatus {
    case notDetermined
    case granted
    case denied
}

// MARK: - MicrophonePermissionChecking

public protocol MicrophonePermissionChecking: AnyObject {
    func requestAccess() async -> Bool
    func authorizationStatus() -> MicPermissionStatus
}

// MARK: - SystemMicrophonePermission

public final class SystemMicrophonePermission: MicrophonePermissionChecking {

    public init() {}

    public func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func authorizationStatus() -> MicPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: return .notDetermined
        case .authorized:    return .granted
        case .denied, .restricted: return .denied
        @unknown default:    return .denied
        }
    }
}
