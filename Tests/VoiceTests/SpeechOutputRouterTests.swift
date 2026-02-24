import Testing
import Foundation
@testable import JARVIS

@Suite("SpeechOutputRouter Tests", .serialized)
struct SpeechOutputRouterTests {

    // MARK: - Helpers

    private func makeRouter(apiKey: String? = "test-key") -> (SpeechOutputRouter, MockSpeechOutput, MockSpeechOutput, MockKeychainHelper) {
        let deepgramOutput = MockSpeechOutput()
        let appleOutput = MockSpeechOutput()
        let keychain = MockKeychainHelper()
        if let key = apiKey {
            try? keychain.save(key: "deepgram_api_key", data: key.data(using: .utf8)!)
        }
        let router = SpeechOutputRouter(
            deepgramOutput: deepgramOutput,
            appleOutput: appleOutput,
            keychain: keychain
        )
        return (router, deepgramOutput, appleOutput, keychain)
    }

    // MARK: - Tests

    @Test("routes to Deepgram when key is present")
    func testRoutesToDeepgramWhenKeyPresent() async throws {
        let (router, deepgramOutput, appleOutput, _) = makeRouter(apiKey: "my-key")
        try await router.speak(text: "test")
        #expect(deepgramOutput.speakCallCount == 1)
        #expect(appleOutput.speakCallCount == 0)
    }

    @Test("routes to Apple when key is missing")
    func testRoutesToAppleWhenKeyMissing() async throws {
        let (router, deepgramOutput, appleOutput, _) = makeRouter(apiKey: nil)
        try await router.speak(text: "test")
        #expect(deepgramOutput.speakCallCount == 0)
        #expect(appleOutput.speakCallCount == 1)
    }

    @Test("falls back to Apple when Deepgram throws")
    func testFallsBackToAppleWhenDeepgramFails() async throws {
        let (router, deepgramOutput, appleOutput, _) = makeRouter(apiKey: "my-key")
        deepgramOutput.speakError = SpeechOutputError.synthesizeFailed("network error")

        try await router.speak(text: "test fallback")

        #expect(deepgramOutput.speakCallCount == 1)
        #expect(appleOutput.speakCallCount == 1)
    }

    @Test("stop() delegates to active backend")
    func testStopDelegatesToActiveBackend() async throws {
        let (router, deepgramOutput, _, _) = makeRouter(apiKey: "my-key")
        try await router.speak(text: "test")
        await router.stop()
        #expect(deepgramOutput.stopCallCount == 1)
    }

    @Test("callbacks are proxied through router")
    func testCallbacksProxied() async throws {
        let (router, deepgramOutput, _, _) = makeRouter(apiKey: "my-key")

        var startedFired = false
        var completedFired = false
        router.onStarted = { startedFired = true }
        router.onCompleted = { completedFired = true }

        try await router.speak(text: "callback test")

        #expect(startedFired == true)
        #expect(completedFired == true)
    }
}
