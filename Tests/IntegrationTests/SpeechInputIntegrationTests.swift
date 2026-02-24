import Testing
import Foundation
import Speech
@testable import JARVIS

@Suite("SpeechInput Integration Tests", .serialized)
struct SpeechInputIntegrationTests {

    // MARK: - Helpers

    private func makeDeepgramInput(key: String = "test-key") -> (DeepgramSpeechInput, MockDeepgramTransport, MockAudioInput) {
        let transport = MockDeepgramTransport()
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        keychain.storedData["deepgram_api_key"] = key.data(using: .utf8)

        let input = DeepgramSpeechInput(
            transport: transport,
            audioInput: audio,
            permissionChecker: mic,
            keychain: keychain
        )
        return (input, transport, audio)
    }

    // MARK: - Tests

    @Test("Full flow: MockAudioInput → DeepgramSpeechInput → partial → final transcript")
    func testFullDeepgramFlow() async throws {
        let (input, transport, audio) = makeDeepgramInput()

        var partials: [String] = []
        var finals: [String] = []
        input.onPartialTranscript = { partials.append($0) }
        input.onFinalTranscript = { finals.append($0) }

        try await input.startListening()

        // Simulate audio frames being captured
        audio.simulateFrames([[100, 200], [300, 400]])
        try await Task.sleep(nanoseconds: 50_000_000)

        // Push partial result from Deepgram
        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"open safari","confidence":0.8,"words":null}]}}
        """
        let interimResp = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(interimResp))
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(partials.last == "open safari")

        // Push final result
        let finalJSON = """
        {"type":"Results","is_final":true,"channel":{"alternatives":[{"transcript":"open safari","confidence":0.99,"words":null}]}}
        """
        let finalResp = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: finalJSON.data(using: .utf8)!)
        transport.push(.results(finalResp))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(finals == ["open safari"])
        #expect(input.isListening == false)
        // Verify audio frames were sent to transport
        #expect(!transport.sentData.isEmpty)
    }

    @Test("Deepgram failure → Apple Speech fallback (via SpeechInputRouter)")
    func testDeepgramFailureFallsBackToApple() async throws {
        let transport = MockDeepgramTransport()
        transport.connectError = URLError(.cannotConnectToHost)
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        keychain.storedData["deepgram_api_key"] = "my-key".data(using: .utf8)

        let deepgramInput = DeepgramSpeechInput(
            transport: transport,
            audioInput: audio,
            permissionChecker: mic,
            keychain: keychain
        )

        let appleInput = AppleSpeechInput(
            recognizer: MockSpeechRecognizer(),
            authRequest: { .authorized },
            audioInput: MockAudioInput(),
            permissionChecker: MockMicrophonePermission()
        )

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        // Should not throw — falls back to Apple
        try await router.startListening()
        #expect(router.isListening == true)
        #expect(transport.connectCalled == false) // Deepgram connect was never called (factory fails before)
        await router.stopListening()
    }

    @Test("Cancel mid-transcription stops without final callback")
    func testCancelMidTranscription() async throws {
        let (input, transport, _) = makeDeepgramInput()

        var finalFired = false
        input.onFinalTranscript = { _ in finalFired = true }

        try await input.startListening()

        // Push a partial
        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"in progress","confidence":0.7,"words":null}]}}
        """
        let interimResp = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(interimResp))
        try await Task.sleep(nanoseconds: 30_000_000)

        await input.cancelListening()
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(finalFired == false)
        #expect(input.isListening == false)
    }

    @Test("UtteranceEnd fires final callback with last seen transcript")
    func testUtteranceEndFiresFinalWithLastSeen() async throws {
        let (input, transport, _) = makeDeepgramInput()

        var finals: [String] = []
        input.onFinalTranscript = { finals.append($0) }

        try await input.startListening()

        // Push partials only (no is_final=true before UtteranceEnd)
        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hey jarvis","confidence":0.85,"words":null}]}}
        """
        let interimResp = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(interimResp))
        try await Task.sleep(nanoseconds: 40_000_000)

        transport.push(.utteranceEnd)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(finals == ["hey jarvis"])
        #expect(input.isListening == false)
    }
}
