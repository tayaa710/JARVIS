import Testing
import Foundation
import Speech
@testable import JARVIS

// MARK: - MockSpeechRecognizer

final class MockSpeechRecognizer: SpeechRecognizerProtocol {

    var isAvailable: Bool = true

    // Stored handler so tests can simulate results
    private(set) var resultHandler: ((SFSpeechRecognitionResult?, Error?) -> Void)?
    private(set) var taskCalled = false

    func recognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        taskCalled = true
        self.resultHandler = resultHandler
        return MockSpeechRecognitionTask()
    }
}

// MARK: - MockSpeechRecognitionTask

final class MockSpeechRecognitionTask: SFSpeechRecognitionTask, @unchecked Sendable {
    private(set) var cancelCalled = false
    override func cancel() { cancelCalled = true }
    override func finish() {}
}

// MARK: - AppleSpeechInput Tests

@Suite("AppleSpeechInput Tests", .serialized)
struct AppleSpeechInputTests {

    private func makeInput(
        grantMic: Bool = true,
        authStatus: SFSpeechRecognizerAuthorizationStatus = .authorized
    ) -> (AppleSpeechInput, MockSpeechRecognizer, MockAudioInput, MockMicrophonePermission) {
        let recognizer = MockSpeechRecognizer()
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        mic.grantAccess = grantMic
        mic.status = grantMic ? .granted : .denied

        let input = AppleSpeechInput(
            recognizer: recognizer,
            authRequest: { authStatus },
            audioInput: audio,
            permissionChecker: mic
        )
        return (input, recognizer, audio, mic)
    }

    // MARK: - Tests

    @Test("startListening requests speech auth")
    func testStartListeningRequestsAuth() async throws {
        var authRequested = false
        let recognizer = MockSpeechRecognizer()
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()

        let input = AppleSpeechInput(
            recognizer: recognizer,
            authRequest: { authRequested = true; return .authorized },
            audioInput: audio,
            permissionChecker: mic
        )
        try await input.startListening()
        #expect(authRequested == true)
        await input.cancelListening()
    }

    @Test("startListening throws when speech auth denied")
    func testStartListeningThrowsWhenAuthDenied() async throws {
        let (input, _, _, _) = makeInput(authStatus: .denied)
        await #expect(throws: SpeechInputError.micPermissionDenied) {
            try await input.startListening()
        }
    }

    @Test("double-start throws alreadyListening")
    func testDoubleStartThrows() async throws {
        let (input, _, _, _) = makeInput()
        try await input.startListening()
        await #expect(throws: SpeechInputError.alreadyListening) {
            try await input.startListening()
        }
        await input.cancelListening()
    }

    @Test("stopListening ends recognition")
    func testStopListeningEndsRecognition() async throws {
        let (input, _, audio, _) = makeInput()
        try await input.startListening()
        #expect(input.isListening == true)
        await input.stopListening()
        #expect(input.isListening == false)
        #expect(audio.stopCaptureCalled > 0)
    }

    @Test("cancelListening ends without firing final callback")
    func testCancelListeningNeverFiresFinalCallback() async throws {
        let (input, _, _, _) = makeInput()
        var finalFired = false
        input.onFinalTranscript = { _ in finalFired = true }

        try await input.startListening()
        await input.cancelListening()
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(finalFired == false)
        #expect(input.isListening == false)
    }
}
