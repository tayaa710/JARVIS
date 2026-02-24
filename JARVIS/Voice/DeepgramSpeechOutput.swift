import Foundation

// MARK: - DeepgramSpeechOutput

/// Synthesises speech via the Deepgram HTTP TTS API.
/// POST https://api.deepgram.com/v1/speak?model=MODEL&encoding=linear16&sample_rate=24000
/// Body: {"text": "..."} → binary 16-bit PCM at 24 kHz mono.
public final class DeepgramSpeechOutput: SpeechOutputProviding {

    // MARK: - SpeechOutputProviding

    public private(set) var isSpeaking: Bool = false
    public var onStarted: (() -> Void)?
    public var onCompleted: (() -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let audioOutput: AudioOutputProviding
    private let keychain: KeychainHelperProtocol

    // MARK: - State

    private var currentTask: Task<Void, Error>?

    // MARK: - Init

    public init(
        apiClient: APIClientProtocol,
        audioOutput: AudioOutputProviding,
        keychain: KeychainHelperProtocol
    ) {
        self.apiClient = apiClient
        self.audioOutput = audioOutput
        self.keychain = keychain
    }

    // MARK: - SpeechOutputProviding

    public func speak(text: String) async throws {
        guard !isSpeaking else { throw SpeechOutputError.alreadySpeaking }

        guard let keyData = try? keychain.read(key: "deepgram_api_key"),
              let apiKey = String(data: keyData, encoding: .utf8),
              !apiKey.isEmpty else {
            throw SpeechOutputError.apiKeyMissing
        }

        let voiceModel = UserDefaults.standard.string(forKey: "ttsVoiceModel")
            ?? DeepgramTTSVoice.default.modelID

        isSpeaking = true
        let chunks = splitText(text)
        var isFirst = true

        Logger.tts.info("DeepgramSpeechOutput: speaking \(chunks.count) chunk(s)")

        do {
            for chunk in chunks {
                let url = "https://api.deepgram.com/v1/speak?model=\(voiceModel)&encoding=linear16&sample_rate=24000"
                let headers = [
                    "Authorization": "Token \(apiKey)",
                    "Content-Type": "application/json"
                ]
                let bodyJSON = ["text": chunk]
                let bodyData = try JSONEncoder().encode(bodyJSON)

                let (audioData, _) = try await apiClient.post(url: url, headers: headers, body: bodyData)

                if isFirst {
                    onStarted?()
                    isFirst = false
                }

                Logger.tts.debug("DeepgramSpeechOutput: playing chunk (\(audioData.count) bytes)")
                try await audioOutput.play(pcmData: audioData, sampleRate: 24000, channelCount: 1)
            }

            isSpeaking = false
            onCompleted?()
            Logger.tts.info("DeepgramSpeechOutput: completed")

        } catch {
            isSpeaking = false
            let ttsError: SpeechOutputError
            if let speechError = error as? SpeechOutputError {
                ttsError = speechError
            } else {
                ttsError = .synthesizeFailed(error.localizedDescription)
            }
            Logger.tts.error("DeepgramSpeechOutput: failed — \(error.localizedDescription)")
            throw ttsError
        }
    }

    public func stop() async {
        currentTask?.cancel()
        currentTask = nil
        audioOutput.stop()
        isSpeaking = false
        Logger.tts.info("DeepgramSpeechOutput: stopped")
    }

    // MARK: - Private

    /// Split text at sentence boundaries if it exceeds 2000 characters.
    func splitText(_ text: String) -> [String] {
        guard text.count > 2000 else { return [text] }

        var chunks: [String] = []
        var remaining = text

        while remaining.count > 2000 {
            let chars = Array(remaining.prefix(2000))
            // Scan backwards for sentence-ending punctuation
            var splitPos: Int? = nil
            for i in stride(from: chars.count - 1, through: 0, by: -1) {
                let ch = chars[i]
                if ch == "." || ch == "!" || ch == "?" {
                    let next = i + 1
                    if next >= chars.count || chars[next] == " " {
                        splitPos = next  // split after punctuation
                        break
                    }
                }
            }

            let count = splitPos ?? 2000
            let chunk = String(chars.prefix(count)).trimmingCharacters(in: .whitespaces)
            chunks.append(chunk)
            remaining = String(remaining.dropFirst(count)).trimmingCharacters(in: .whitespaces)
        }

        if !remaining.isEmpty {
            chunks.append(remaining)
        }

        return chunks.filter { !$0.isEmpty }
    }
}
