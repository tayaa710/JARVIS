// MARK: - WakeWordError

public enum WakeWordError: Error, Equatable {
    case microphonePermissionDenied
    case engineInitFailed(String)
    case accessKeyMissing
    case alreadyListening
}

// MARK: - WakeWordDetecting

public protocol WakeWordDetecting: AnyObject {
    func start() async throws
    func stop() async
    func pause() async
    func resume() async throws
    var isListening: Bool { get }
    var onWakeWordDetected: (@Sendable () -> Void)? { get set }
    var onError: (@Sendable (Error) -> Void)? { get set }
}
