import Foundation

// MARK: - SpeechOutputRouter

/// Routes TTS to Deepgram (if API key is present) or Apple Speech (fallback).
public final class SpeechOutputRouter: SpeechOutputProviding {

    // MARK: - SpeechOutputProviding

    public private(set) var isSpeaking: Bool = false
    public var onStarted: (() -> Void)?
    public var onCompleted: (() -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let deepgramOutput: any SpeechOutputProviding
    private let appleOutput: any SpeechOutputProviding
    private let keychain: KeychainHelperProtocol

    // MARK: - Internal State

    private var activeBackend: (any SpeechOutputProviding)?

    // MARK: - Init

    public init(
        deepgramOutput: any SpeechOutputProviding,
        appleOutput: any SpeechOutputProviding,
        keychain: KeychainHelperProtocol
    ) {
        self.deepgramOutput = deepgramOutput
        self.appleOutput = appleOutput
        self.keychain = keychain
    }

    // MARK: - SpeechOutputProviding

    public func speak(text: String) async throws {
        let hasKey = hasDeepgramKey()

        if hasKey {
            do {
                wireCallbacks(to: deepgramOutput)
                isSpeaking = true
                try await deepgramOutput.speak(text: text)
                activeBackend = deepgramOutput
                isSpeaking = false
                Logger.tts.info("SpeechOutputRouter: used Deepgram backend")
            } catch {
                // Fall back to Apple TTS on Deepgram failure
                Logger.tts.warning("SpeechOutputRouter: Deepgram failed (\(error.localizedDescription)), falling back to Apple")
                isSpeaking = true
                wireCallbacks(to: appleOutput)
                try await appleOutput.speak(text: text)
                activeBackend = appleOutput
                isSpeaking = false
                Logger.tts.info("SpeechOutputRouter: used Apple backend (fallback)")
            }
        } else {
            isSpeaking = true
            wireCallbacks(to: appleOutput)
            try await appleOutput.speak(text: text)
            activeBackend = appleOutput
            isSpeaking = false
            Logger.tts.info("SpeechOutputRouter: used Apple backend (no Deepgram key)")
        }
    }

    public func stop() async {
        await activeBackend?.stop()
        isSpeaking = false
        activeBackend = nil
        Logger.tts.info("SpeechOutputRouter: stopped")
    }

    // MARK: - Private

    private func hasDeepgramKey() -> Bool {
        guard let data = try? keychain.read(key: "deepgram_api_key"),
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return false }
        return true
    }

    private func wireCallbacks(to output: any SpeechOutputProviding) {
        output.onStarted = { [weak self] in self?.onStarted?() }
        output.onCompleted = { [weak self] in self?.onCompleted?() }
        output.onError = { [weak self] error in self?.onError?(error) }
    }
}
