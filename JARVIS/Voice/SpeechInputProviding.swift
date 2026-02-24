// MARK: - SpeechInputError

public enum SpeechInputError: Error, Equatable {
    case micPermissionDenied
    case apiKeyMissing
    case connectionFailed(String)
    case recognitionFailed(String)
    case alreadyListening
}

// MARK: - SpeechInputProviding

public protocol SpeechInputProviding: AnyObject {
    var isListening: Bool { get }
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func startListening() async throws
    func stopListening() async
    func cancelListening() async
}
