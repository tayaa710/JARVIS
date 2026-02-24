import Foundation
import Speech
import AVFoundation

// MARK: - SpeechRecognizerProtocol

public protocol SpeechRecognizerProtocol: AnyObject {
    var isAvailable: Bool { get }
    func recognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SFSpeechRecognitionTask
}

extension SFSpeechRecognizer: SpeechRecognizerProtocol {}

// MARK: - AppleSpeechInput

public final class AppleSpeechInput: SpeechInputProviding {

    // MARK: - SpeechInputProviding

    public private(set) var isListening: Bool = false
    public var onPartialTranscript: ((String) -> Void)?
    public var onFinalTranscript: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let recognizer: any SpeechRecognizerProtocol
    private let authRequest: () async -> SFSpeechRecognizerAuthorizationStatus
    private let audioInput: AudioInputProviding
    private let permissionChecker: MicrophonePermissionChecking

    // MARK: - Internal State

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Task<Void, Never>?
    private var isCancelling: Bool = false

    // MARK: - Init (production)

    public convenience init(
        audioInput: AudioInputProviding,
        permissionChecker: MicrophonePermissionChecking
    ) {
        let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.init(
            recognizer: recognizer,
            authRequest: {
                await withCheckedContinuation { cont in
                    SFSpeechRecognizer.requestAuthorization { status in
                        cont.resume(returning: status)
                    }
                }
            },
            audioInput: audioInput,
            permissionChecker: permissionChecker
        )
    }

    // MARK: - Init (testable)

    public init(
        recognizer: any SpeechRecognizerProtocol,
        authRequest: @escaping () async -> SFSpeechRecognizerAuthorizationStatus,
        audioInput: AudioInputProviding,
        permissionChecker: MicrophonePermissionChecking
    ) {
        self.recognizer = recognizer
        self.authRequest = authRequest
        self.audioInput = audioInput
        self.permissionChecker = permissionChecker
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

        // Request speech recognition authorization
        let status = await authRequest()
        guard status == .authorized else {
            throw SpeechInputError.micPermissionDenied
        }

        isListening = true
        isCancelling = false

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        // Create recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                guard !self.isCancelling else { return }
                DispatchQueue.main.async {
                    self.onError?(error)
                }
                return
            }

            guard let result else { return }
            let transcript = result.bestTranscription.formattedString

            if result.isFinal {
                self.silenceTimer?.cancel()
                self.silenceTimer = nil
                self.isListening = false
                self.audioInput.stopCapture()
                DispatchQueue.main.async {
                    self.onFinalTranscript?(transcript)
                }
                Logger.stt.info("AppleSpeechInput: final — \"\(transcript)\"")
            } else {
                DispatchQueue.main.async {
                    self.onPartialTranscript?(transcript)
                }
                // Reset 2-second silence timer on each partial result
                self.silenceTimer?.cancel()
                self.silenceTimer = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard let self, !Task.isCancelled, self.isListening else { return }
                    let finalText = transcript
                    self.isListening = false
                    self.audioInput.stopCapture()
                    self.recognitionRequest?.endAudio()
                    DispatchQueue.main.async {
                        self.onFinalTranscript?(finalText)
                    }
                    Logger.stt.info("AppleSpeechInput: silence timer fired — \"\(finalText)\"")
                }
            }
        }

        // Start audio capture and feed PCM buffers to the recognizer
        do {
            try audioInput.startCapture(frameSize: 512, sampleRate: 16000) { [weak self] pcm in
                guard let self, self.isListening else { return }
                if let buffer = Self.makePCMBuffer(from: pcm) {
                    self.recognitionRequest?.append(buffer)
                }
            }
        } catch {
            isListening = false
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            throw SpeechInputError.recognitionFailed(error.localizedDescription)
        }

        Logger.stt.info("AppleSpeechInput: started")
    }

    public func stopListening() async {
        guard isListening else { return }
        isCancelling = false
        isListening = false
        silenceTimer?.cancel()
        silenceTimer = nil
        audioInput.stopCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        Logger.stt.info("AppleSpeechInput: stopped")
    }

    public func cancelListening() async {
        guard isListening else { return }
        isCancelling = true
        isListening = false
        silenceTimer?.cancel()
        silenceTimer = nil
        audioInput.stopCapture()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isCancelling = false
        Logger.stt.info("AppleSpeechInput: cancelled")
    }

    // MARK: - Private

    private static func makePCMBuffer(from samples: [Int16]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else { return nil }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let ptr = buffer.int16ChannelData else { return nil }
        samples.withUnsafeBufferPointer { src in
            guard let base = src.baseAddress else { return }
            ptr[0].initialize(from: base, count: samples.count)
        }
        return buffer
    }
}
