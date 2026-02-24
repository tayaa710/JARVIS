import Testing
import Foundation
import Speech
@testable import JARVIS

@Suite("SpeechInputRouter Tests", .serialized)
struct SpeechInputRouterTests {

    // MARK: - Helpers

    private func makeDeepgramInput(
        key: String? = "test-deepgram-key",
        connectError: Error? = nil
    ) -> (DeepgramSpeechInput, MockDeepgramTransport, MockKeychainHelper) {
        let transport = MockDeepgramTransport()
        transport.connectError = connectError
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        if let key {
            keychain.storedData["deepgram_api_key"] = key.data(using: .utf8)
        }
        let input = DeepgramSpeechInput(
            transport: transport,
            audioInput: audio,
            permissionChecker: mic,
            keychain: keychain
        )
        return (input, transport, keychain)
    }

    private func makeAppleInput() -> AppleSpeechInput {
        AppleSpeechInput(
            recognizer: MockSpeechRecognizer(),
            authRequest: { .authorized },
            audioInput: MockAudioInput(),
            permissionChecker: MockMicrophonePermission()
        )
    }

    // MARK: - Tests

    @Test("routes to Deepgram when API key present")
    func testRoutesToDeepgramWhenKeyPresent() async throws {
        let (deepgramInput, transport, keychain) = makeDeepgramInput(key: "my-key")
        let appleInput = makeAppleInput()

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        try await router.startListening()
        #expect(transport.connectCalled == true)
        #expect(router.isListening == true)
        await router.stopListening()
    }

    @Test("falls back to Apple when API key missing")
    func testFallsBackToAppleWhenKeyMissing() async throws {
        let (deepgramInput, transport, keychain) = makeDeepgramInput(key: nil)
        let appleInput = makeAppleInput()

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        try await router.startListening()
        // Deepgram should NOT have been called (no key)
        #expect(transport.connectCalled == false)
        #expect(router.isListening == true)
        await router.stopListening()
    }

    @Test("falls back to Apple when Deepgram throws on start")
    func testFallsBackToAppleWhenDeepgramFails() async throws {
        let (deepgramInput, transport, keychain) = makeDeepgramInput(
            key: "my-key",
            connectError: URLError(.cannotConnectToHost)
        )
        let appleInput = makeAppleInput()

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        try await router.startListening()
        #expect(transport.connectCalled == false)  // connect throws so connectCalled stays false
        #expect(router.isListening == true)
        await router.stopListening()
    }

    @Test("stopListening delegates to active backend")
    func testStopListeningDelegatesToBackend() async throws {
        let (deepgramInput, _, keychain) = makeDeepgramInput(key: "key")
        let appleInput = makeAppleInput()

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        try await router.startListening()
        await router.stopListening()
        #expect(router.isListening == false)
    }

    @Test("partial and final callbacks are proxied through router")
    func testCallbacksProxiedCorrectly() async throws {
        let (deepgramInput, transport, keychain) = makeDeepgramInput(key: "key")
        let appleInput = makeAppleInput()

        let router = SpeechInputRouter(
            deepgramInput: deepgramInput,
            appleInput: appleInput,
            keychain: keychain
        )

        var partials: [String] = []
        var finals: [String] = []
        router.onPartialTranscript = { partials.append($0) }
        router.onFinalTranscript = { finals.append($0) }

        try await router.startListening()

        // Simulate a partial from Deepgram
        let interimJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"test","confidence":0.9,"words":null}]}}
        """
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: interimJSON.data(using: .utf8)!)
        transport.push(.results(response))
        try await Task.sleep(nanoseconds: 80_000_000)

        #expect(partials == ["test"])
        await router.cancelListening()
    }
}
