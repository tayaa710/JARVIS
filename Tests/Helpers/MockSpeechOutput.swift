import Foundation
@testable import JARVIS

/// Mock SpeechOutputProviding for TTS tests.
final class MockSpeechOutput: SpeechOutputProviding {

    private(set) var isSpeaking: Bool = false
    var onStarted: (() -> Void)?
    var onCompleted: (() -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var speakCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastSpokenText: String?

    var speakError: Error?

    func speak(text: String) async throws {
        speakCallCount += 1
        lastSpokenText = text
        if let error = speakError { throw error }
        isSpeaking = true
        onStarted?()
        isSpeaking = false
        onCompleted?()
    }

    func stop() async {
        stopCallCount += 1
        isSpeaking = false
    }

    // MARK: - Test helpers

    func simulateStarted() {
        isSpeaking = true
        onStarted?()
    }

    func simulateCompleted() {
        isSpeaking = false
        onCompleted?()
    }

    func simulateError(_ error: Error) {
        isSpeaking = false
        onError?(error)
    }
}
