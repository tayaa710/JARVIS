import Testing
import AVFoundation
@testable import JARVIS

@Suite("AppleSpeechOutput Tests", .serialized)
struct AppleSpeechOutputTests {

    // MARK: - Helpers

    @MainActor
    private func makeOutput() -> (AppleSpeechOutput, MockSpeechSynthesizer) {
        let mock = MockSpeechSynthesizer()
        let output = AppleSpeechOutput(synthesizerFactory: { mock })
        return (output, mock)
    }

    // MARK: - Tests

    @Test("speak() creates utterance with correct text")
    @MainActor
    func testSpeakCreatesUtterance() async throws {
        let (output, mock) = makeOutput()
        mock.completesImmediately = true

        try await output.speak(text: "Hello from JARVIS")

        #expect(mock.lastUtteranceText == "Hello from JARVIS")
    }

    @Test("speak() calls speak on synthesizer")
    @MainActor
    func testSpeakCallsSynthesizer() async throws {
        let (output, mock) = makeOutput()
        mock.completesImmediately = true

        try await output.speak(text: "test")

        #expect(mock.speakCallCount == 1)
    }

    @Test("stop() calls stopSpeaking")
    @MainActor
    func testStopCallsStopSpeaking() {
        let (output, mock) = makeOutput()
        output.stop()
        #expect(mock.stopSpeakingCalled == true)
    }

    @Test("onStarted and onCompleted fire when speaking")
    @MainActor
    func testCallbacksFire() async throws {
        let (output, mock) = makeOutput()
        mock.completesImmediately = true

        var startedFired = false
        var completedFired = false
        output.onStarted = { startedFired = true }
        output.onCompleted = { completedFired = true }

        try await output.speak(text: "callbacks test")

        #expect(startedFired == true)
        #expect(completedFired == true)
    }

    @Test("isSpeaking is false after completion")
    @MainActor
    func testIsSpeakingAfterCompletion() async throws {
        let (output, mock) = makeOutput()
        mock.completesImmediately = true

        try await output.speak(text: "done")

        #expect(output.isSpeaking == false)
    }
}
