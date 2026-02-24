import AVFoundation
@testable import JARVIS

/// Mock for SpeechSynthesizing protocol — drives AVSpeechSynthesizerDelegate callbacks synchronously.
@MainActor
final class MockSpeechSynthesizer: SpeechSynthesizing {

    var isSpeaking: Bool = false
    var delegate: AVSpeechSynthesizerDelegate?

    private(set) var speakCallCount = 0
    private(set) var lastUtteranceText: String?
    private(set) var stopSpeakingCalled = false

    /// When true, immediately fires didFinish on the delegate after speak().
    var completesImmediately = false

    func speak(_ utterance: AVSpeechUtterance) {
        speakCallCount += 1
        lastUtteranceText = utterance.speechString
        isSpeaking = true
        if completesImmediately {
            // Simulate immediate completion
            isSpeaking = false
            delegate?.speechSynthesizer?(AVSpeechSynthesizer(), didFinish: utterance)
        }
    }

    @discardableResult
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        stopSpeakingCalled = true
        isSpeaking = false
        return true
    }
}
