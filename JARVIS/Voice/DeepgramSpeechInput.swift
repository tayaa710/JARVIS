import Foundation

// MARK: - DeepgramSpeechInput

public final class DeepgramSpeechInput: SpeechInputProviding {

    // MARK: - SpeechInputProviding

    public private(set) var isListening: Bool = false
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let transport: DeepgramTransporting
    private let audioInput: AudioInputProviding
    private let permissionChecker: MicrophonePermissionChecking
    private let keychain: KeychainHelperProtocol

    // MARK: - Internal State

    private var receiveTask: Task<Void, Never>?
    private var lastSeenTranscript: String = ""
    private var isStopping: Bool = false

    // MARK: - Init

    public init(
        transport: DeepgramTransporting,
        audioInput: AudioInputProviding,
        permissionChecker: MicrophonePermissionChecking,
        keychain: KeychainHelperProtocol
    ) {
        self.transport = transport
        self.audioInput = audioInput
        self.permissionChecker = permissionChecker
        self.keychain = keychain
    }

    // MARK: - SpeechInputProviding

    public func startListening() async throws {
        guard !isListening else { throw SpeechInputError.alreadyListening }

        // Check microphone permission
        switch permissionChecker.authorizationStatus() {
        case .denied:
            throw SpeechInputError.micPermissionDenied
        case .notDetermined:
            let granted = await permissionChecker.requestAccess()
            guard granted else { throw SpeechInputError.micPermissionDenied }
        case .granted:
            break
        }

        // Read API key from keychain
        guard let keyData = try? keychain.read(key: "deepgram_api_key"),
              let apiKey = String(data: keyData, encoding: .utf8),
              !apiKey.isEmpty else {
            throw SpeechInputError.apiKeyMissing
        }

        // Build connection URL
        let urlString = "wss://api.deepgram.com/v1/listen" +
            "?encoding=linear16&sample_rate=16000&channels=1" +
            "&interim_results=true&model=nova-3&endpointing=2000&vad_events=true"
        guard let url = URL(string: urlString) else {
            throw SpeechInputError.connectionFailed("Invalid URL")
        }

        // Connect WebSocket
        do {
            try await transport.connect(
                url: url,
                headers: ["Authorization": "Token \(apiKey)"]
            )
        } catch {
            throw SpeechInputError.connectionFailed(error.localizedDescription)
        }

        isListening = true
        isStopping = false
        lastSeenTranscript = ""

        Logger.stt.info("DeepgramSpeechInput: connected, starting receive loop")

        // Start receive loop
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await message in self.transport.receive() {
                    let shouldStop = self.handleMessage(message)
                    if shouldStop || !self.isListening { break }
                }
            } catch {
                guard !self.isStopping else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(error)
                }
            }
            // Transport cleanup when loop exits
            await self.transport.close()
            Logger.stt.info("DeepgramSpeechInput: receive loop exited")
        }

        // Start audio capture — stream PCM frames as binary WebSocket messages
        do {
            try audioInput.startCapture(frameSize: 512, sampleRate: 16000) { [weak self] pcm in
                guard let self, self.isListening else { return }
                let data = pcm.withUnsafeBufferPointer { Data(buffer: $0) }
                Task { try? await self.transport.send(data: data) }
            }
        } catch {
            isListening = false
            receiveTask?.cancel()
            receiveTask = nil
            throw SpeechInputError.connectionFailed(error.localizedDescription)
        }

        Logger.stt.info("DeepgramSpeechInput: audio capture started")
    }

    public func stopListening() async {
        guard isListening else { return }
        isStopping = true
        isListening = false
        audioInput.stopCapture()
        receiveTask?.cancel()
        receiveTask = nil
        await transport.close()
        isStopping = false
        Logger.stt.info("DeepgramSpeechInput: stopped")
    }

    public func cancelListening() async {
        guard isListening else { return }
        isStopping = true
        isListening = false
        audioInput.stopCapture()
        receiveTask?.cancel()
        receiveTask = nil
        await transport.close()
        isStopping = false
        Logger.stt.info("DeepgramSpeechInput: cancelled")
    }

    // MARK: - Private

    /// Handles a Deepgram message. Returns true if the receive loop should stop.
    @discardableResult
    private func handleMessage(_ message: DeepgramMessage) -> Bool {
        switch message {
        case .results(let response):
            guard let transcript = response.channel?.alternatives.first?.transcript,
                  !transcript.isEmpty else { return false }

            if response.isFinal == true {
                // Final chunk — fire final callback and stop
                isListening = false
                audioInput.stopCapture()
                DispatchQueue.main.async { [weak self] in
                    self?.onFinalTranscript?(transcript)
                }
                Logger.stt.info("DeepgramSpeechInput: final transcript — \"\(transcript)\"")
                return true
            } else {
                // Interim result — update partial display
                lastSeenTranscript = transcript
                DispatchQueue.main.async { [weak self] in
                    self?.onPartialTranscript?(transcript)
                }
            }
            return false

        case .utteranceEnd:
            // UtteranceEnd fires if we haven't already finalized via is_final=true
            guard isListening else { return true }
            let text = lastSeenTranscript
            isListening = false
            audioInput.stopCapture()
            DispatchQueue.main.async { [weak self] in
                self?.onFinalTranscript?(text)
            }
            Logger.stt.info("DeepgramSpeechInput: utterance end — \"\(text)\"")
            return true

        case .error(let msg):
            Logger.stt.error("DeepgramSpeechInput: server error — \(msg)")
            DispatchQueue.main.async { [weak self] in
                self?.onError?(SpeechInputError.recognitionFailed(msg))
            }
            return false

        case .speechStarted:
            Logger.stt.debug("DeepgramSpeechInput: speech started")
            return false

        case .metadata, .unknown:
            return false
        }
    }
}
