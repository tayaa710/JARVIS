import Foundation
@testable import JARVIS

/// Mock SpeechInputProviding for ChatViewModel STT tests.
final class MockSpeechInput: SpeechInputProviding {

    private(set) var isListening: Bool = false
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var startListeningCalled = false
    private(set) var stopListeningCalled = false
    private(set) var cancelListeningCalled = false

    var startError: Error?

    func startListening() async throws {
        startListeningCalled = true
        if let error = startError { throw error }
        isListening = true
    }

    func stopListening() async {
        stopListeningCalled = true
        isListening = false
    }

    func cancelListening() async {
        cancelListeningCalled = true
        isListening = false
    }

    // MARK: - Test helpers

    func simulatePartial(_ text: String) {
        onPartialTranscript?(text)
    }

    func simulateFinal(_ text: String) {
        isListening = false
        onFinalTranscript?(text)
    }

    func simulateError(_ error: Error) {
        isListening = false
        onError?(error)
    }
}
