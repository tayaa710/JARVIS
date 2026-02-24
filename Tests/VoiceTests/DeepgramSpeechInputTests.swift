import Testing
import Foundation
@testable import JARVIS

@Suite("DeepgramSpeechInput Tests", .serialized)
struct DeepgramSpeechInputTests {

    // MARK: - Helpers

    private func makeInput(
        grantMic: Bool = true,
        deepgramKey: String? = "test-deepgram-key",
        transportConnectError: Error? = nil
    ) -> (DeepgramSpeechInput, MockDeepgramTransport, MockAudioInput, MockMicrophonePermission, MockKeychainHelper) {
        let transport = MockDeepgramTransport()
        transport.connectError = transportConnectError

        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        mic.grantAccess = grantMic
        mic.status = grantMic ? .granted : .denied
        // status and grantAccess are set independently in MockMicrophonePermission

        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil  // Reset — use storedData instead
        if let key = deepgramKey {
            keychain.storedData["deepgram_api_key"] = key.data(using: .utf8)
        }

        let input = DeepgramSpeechInput(
            transport: transport,
            audioInput: audio,
            permissionChecker: mic,
            keychain: keychain
        )
        return (input, transport, audio, mic, keychain)
    }

    // MARK: - Tests

    @Test("startListening reads API key from keychain")
    func testStartListeningReadsAPIKey() async throws {
        let (input, transport, _, _, keychain) = makeInput(deepgramKey: "my-key-123")
        try await input.startListening()
        #expect(transport.connectCalled == true)
        #expect(transport.connectedHeaders["Authorization"] == "Token my-key-123")
        await input.cancelListening()
    }

    @Test("startListening throws apiKeyMissing when key absent")
    func testStartListeningThrowsWhenKeyAbsent() async throws {
        let (input, _, _, _, _) = makeInput(deepgramKey: nil)
        await #expect(throws: SpeechInputError.apiKeyMissing) {
            try await input.startListening()
        }
    }

    @Test("startListening throws micPermissionDenied when denied")
    func testStartListeningThrowsWhenMicDenied() async throws {
        let (input, _, _, _, _) = makeInput(grantMic: false)
        await #expect(throws: SpeechInputError.micPermissionDenied) {
            try await input.startListening()
        }
    }

    @Test("startListening throws alreadyListening on double-start")
    func testStartListeningThrowsOnDoubleStart() async throws {
        let (input, _, _, _, _) = makeInput()
        try await input.startListening()
        await #expect(throws: SpeechInputError.alreadyListening) {
            try await input.startListening()
        }
        await input.cancelListening()
    }

    @Test("audio frames are sent as binary data to transport")
    func testAudioFramesSentAsBinaryData() async throws {
        let (input, transport, audio, _, _) = makeInput()
        try await input.startListening()

        // Simulate PCM frame
        audio.simulateFrames([[100, 200, 300]])
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(!transport.sentData.isEmpty)
        await input.cancelListening()
    }

    @Test("partial transcript callback fires on interim result")
    func testPartialTranscriptCallbackFires() async throws {
        let (input, transport, _, _, _) = makeInput()

        var partials: [String] = []
        input.onPartialTranscript = { partials.append($0) }

        try await input.startListening()

        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hello","confidence":0.9,"words":null}]}}
        """
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(response))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(partials == ["hello"])
        await input.cancelListening()
    }

    @Test("final transcript callback fires on is_final result")
    func testFinalTranscriptCallbackFiresOnIsFinal() async throws {
        let (input, transport, _, _, _) = makeInput()

        var finals: [String] = []
        input.onFinalTranscript = { finals.append($0) }

        try await input.startListening()

        let finalJSON = """
        {"type":"Results","is_final":true,"channel":{"alternatives":[{"transcript":"open safari","confidence":0.99,"words":null}]}}
        """
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: finalJSON.data(using: .utf8)!)
        transport.push(.results(response))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(finals == ["open safari"])
        #expect(input.isListening == false)
    }

    @Test("utteranceEnd triggers stop and final callback")
    func testUtteranceEndTriggersStopAndFinalCallback() async throws {
        let (input, transport, _, _, _) = makeInput()

        // Provide a partial so lastSeenTranscript is populated
        var partials: [String] = []
        var finals: [String] = []
        input.onPartialTranscript = { partials.append($0) }
        input.onFinalTranscript = { finals.append($0) }

        try await input.startListening()

        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hey jarvis","confidence":0.9,"words":null}]}}
        """
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(response))
        try await Task.sleep(nanoseconds: 50_000_000)

        transport.push(.utteranceEnd)
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(finals == ["hey jarvis"])
        #expect(input.isListening == false)
    }

    @Test("stopListening stops audio capture")
    func testStopListeningStopsAudio() async throws {
        let (input, _, audio, _, _) = makeInput()
        try await input.startListening()
        await input.stopListening()
        #expect(audio.stopCaptureCalled > 0)
        #expect(input.isListening == false)
    }

    @Test("cancelListening stops without firing final callback")
    func testCancelListeningNeverFiresFinalCallback() async throws {
        let (input, transport, _, _, _) = makeInput()

        var finalFired = false
        input.onFinalTranscript = { _ in finalFired = true }

        try await input.startListening()

        // Push a partial
        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"test","confidence":0.9,"words":null}]}}
        """
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(response))
        try await Task.sleep(nanoseconds: 30_000_000)

        await input.cancelListening()
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(finalFired == false)
        #expect(input.isListening == false)
    }

    @Test("error callback fires on transport error")
    func testErrorCallbackFiresOnTransportError() async throws {
        let (input, transport, _, _, _) = makeInput()

        var gotError = false
        input.onError = { _ in gotError = true }

        try await input.startListening()
        // Small delay to let the receive loop Task start and set up the continuation
        try await Task.sleep(nanoseconds: 20_000_000)
        transport.push(.error("Deepgram server error"))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(gotError == true)
        await input.cancelListening()
    }
}

