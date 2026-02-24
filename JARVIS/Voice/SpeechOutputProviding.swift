// MARK: - SpeechOutputError

public enum SpeechOutputError: Error, Equatable {
    case apiKeyMissing
    case synthesizeFailed(String)
    case alreadySpeaking
    case textTooLong
}

// MARK: - SpeechOutputProviding

public protocol SpeechOutputProviding: AnyObject {
    var isSpeaking: Bool { get }
    var onStarted: (() -> Void)? { get set }
    var onCompleted: (() -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func speak(text: String) async throws
    func stop() async
}
