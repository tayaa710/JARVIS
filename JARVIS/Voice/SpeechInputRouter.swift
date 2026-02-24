import Foundation

// MARK: - SpeechInputRouter

/// Routes STT to Deepgram (if API key is present) or Apple Speech (fallback).
public final class SpeechInputRouter: SpeechInputProviding {

    // MARK: - SpeechInputProviding

    public private(set) var isListening: Bool = false
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let deepgramInput: DeepgramSpeechInput
    private let appleInput: AppleSpeechInput
    private let keychain: KeychainHelperProtocol

    // MARK: - Internal State

    private var activeBackend: (any SpeechInputProviding)?

    // MARK: - Init

    public init(
        deepgramInput: DeepgramSpeechInput,
        appleInput: AppleSpeechInput,
        keychain: KeychainHelperProtocol
    ) {
        self.deepgramInput = deepgramInput
        self.appleInput = appleInput
        self.keychain = keychain
    }

    // MARK: - SpeechInputProviding

    public func startListening() async throws {
        guard !isListening else { throw SpeechInputError.alreadyListening }

        let hasKey = hasDeepgramKey()

        if hasKey {
            do {
                wireCallbacks(to: deepgramInput)
                try await deepgramInput.startListening()
                activeBackend = deepgramInput
                Logger.stt.info("SpeechInputRouter: using Deepgram backend")
            } catch {
                // Fall back to Apple Speech on any Deepgram failure
                Logger.stt.warning("SpeechInputRouter: Deepgram failed (\(error)), falling back to Apple Speech")
                wireCallbacks(to: appleInput)
                try await appleInput.startListening()
                activeBackend = appleInput
                Logger.stt.info("SpeechInputRouter: using Apple Speech backend (fallback)")
            }
        } else {
            wireCallbacks(to: appleInput)
            try await appleInput.startListening()
            activeBackend = appleInput
            Logger.stt.info("SpeechInputRouter: using Apple Speech backend (no Deepgram key)")
        }

        isListening = true
    }

    public func stopListening() async {
        guard isListening else { return }
        await activeBackend?.stopListening()
        isListening = false
        activeBackend = nil
    }

    public func cancelListening() async {
        guard isListening else { return }
        await activeBackend?.cancelListening()
        isListening = false
        activeBackend = nil
    }

    // MARK: - Private

    private func hasDeepgramKey() -> Bool {
        guard let data = try? keychain.read(key: "deepgram_api_key"),
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return false }
        return true
    }

    private func wireCallbacks(to input: DeepgramSpeechInput) {
        input.onPartialTranscript = { [weak self] text in self?.onPartialTranscript?(text) }
        input.onFinalTranscript = { [weak self] text in self?.onFinalTranscript?(text) }
        input.onError = { [weak self] error in self?.onError?(error) }
    }

    private func wireCallbacks(to input: AppleSpeechInput) {
        input.onPartialTranscript = { [weak self] text in self?.onPartialTranscript?(text) }
        input.onFinalTranscript = { [weak self] text in self?.onFinalTranscript?(text) }
        input.onError = { [weak self] error in self?.onError?(error) }
    }
}
