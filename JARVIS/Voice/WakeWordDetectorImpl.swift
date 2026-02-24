import Foundation

// MARK: - WakeWordDetectorImpl

public final class WakeWordDetectorImpl: WakeWordDetecting {

    // MARK: - Properties

    private let engine: WakeWordEngine
    private let audioInput: AudioInputProviding
    private let permissionChecker: MicrophonePermissionChecking

    public private(set) var isListening: Bool = false
    public var onWakeWordDetected: (@Sendable () -> Void)?
    public var onError: (@Sendable (Error) -> Void)?

    // MARK: - Init

    public init(
        engine: WakeWordEngine,
        audioInput: AudioInputProviding,
        permissionChecker: MicrophonePermissionChecking
    ) {
        self.engine = engine
        self.audioInput = audioInput
        self.permissionChecker = permissionChecker
    }

    // MARK: - WakeWordDetecting

    public func start() async throws {
        guard !isListening else {
            Logger.wakeWord.warning("start() called while already listening")
            throw WakeWordError.alreadyListening
        }
        let granted = await permissionChecker.requestAccess()
        guard granted else {
            Logger.wakeWord.error("Microphone permission denied")
            throw WakeWordError.microphonePermissionDenied
        }
        try beginCapture()
    }

    public func stop() async {
        audioInput.stopCapture()
        engine.delete()
        isListening = false
        Logger.wakeWord.info("Stopped wake word detection")
    }

    public func pause() async {
        audioInput.stopCapture()
        isListening = false
        Logger.wakeWord.info("Paused wake word detection (engine kept alive)")
    }

    public func resume() async throws {
        try beginCapture()
    }

    // MARK: - Private

    private func beginCapture() throws {
        let frameSize = Int(engine.frameLength)
        let sampleRate = Int(engine.sampleRate)

        try audioInput.startCapture(frameSize: frameSize, sampleRate: sampleRate) { [weak self] pcm in
            guard let self else { return }
            do {
                let index = try self.engine.process(pcm: pcm)
                if index >= 0 {
                    Logger.wakeWord.info("Wake word detected at index \(index)")
                    DispatchQueue.main.async {
                        self.onWakeWordDetected?()
                    }
                }
            } catch {
                Logger.wakeWord.error("Engine process error: \(error)")
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            }
        }
        isListening = true
        Logger.wakeWord.info("Wake word detection started (frameSize: \(frameSize), sampleRate: \(sampleRate))")
    }
}
