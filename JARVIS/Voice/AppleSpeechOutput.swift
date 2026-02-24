import Foundation
import AVFoundation

// MARK: - SpeechSynthesizing

/// Protocol wrapping AVSpeechSynthesizer for testability.
public protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    var delegate: AVSpeechSynthesizerDelegate? { get set }
    func speak(_ utterance: AVSpeechUtterance)
    @discardableResult func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

extension AVSpeechSynthesizer: SpeechSynthesizing {}

// MARK: - SpeechSynthesizerDelegate (bridge async)

private final class SpeechSynthesizerBridge: NSObject, AVSpeechSynthesizerDelegate {
    var onFinished: (() -> Void)?
    var onCancelled: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinished?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onCancelled?()
    }
}

// MARK: - AppleSpeechOutput

/// TTS fallback using AVSpeechSynthesizer (no network required).
public final class AppleSpeechOutput: SpeechOutputProviding {

    // MARK: - SpeechOutputProviding

    public private(set) var isSpeaking: Bool = false
    public var onStarted: (() -> Void)?
    public var onCompleted: (() -> Void)?
    public var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let synthesizer: any SpeechSynthesizing
    private let bridge: SpeechSynthesizerBridge

    // MARK: - Init

    public init(synthesizerFactory: () -> any SpeechSynthesizing = { AVSpeechSynthesizer() }) {
        let synth = synthesizerFactory()
        self.synthesizer = synth
        self.bridge = SpeechSynthesizerBridge()
        synth.delegate = bridge
    }

    // MARK: - SpeechOutputProviding

    public func speak(text: String) async throws {
        guard !isSpeaking else { throw SpeechOutputError.alreadySpeaking }
        guard !text.isEmpty else { return }

        isSpeaking = true
        onStarted?()

        Logger.tts.info("AppleSpeechOutput: speaking \(text.count) chars")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            bridge.onFinished = { [weak self] in
                self?.isSpeaking = false
                Logger.tts.debug("AppleSpeechOutput: finished")
                cont.resume()
            }
            bridge.onCancelled = { [weak self] in
                self?.isSpeaking = false
                Logger.tts.debug("AppleSpeechOutput: cancelled")
                cont.resume()
            }
            synthesizer.speak(utterance)
        }

        onCompleted?()
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        Logger.tts.info("AppleSpeechOutput: stopped")
    }
}
