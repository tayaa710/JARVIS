import Testing
import Foundation
@testable import JARVIS

@Suite("DeepgramSpeechOutput Tests", .serialized)
struct DeepgramSpeechOutputTests {

    // MARK: - Helpers

    private static let dummyURL = URL(string: "https://api.deepgram.com")!

    private func makeOutput(apiKey: String? = "test-key") -> (DeepgramSpeechOutput, MockAPIClient, MockAudioOutput, MockKeychainHelper) {
        let apiClient = MockAPIClient()
        let audioOutput = MockAudioOutput()
        let keychain = MockKeychainHelper()
        if let key = apiKey {
            try? keychain.save(key: "deepgram_api_key", data: key.data(using: .utf8)!)
        }
        let output = DeepgramSpeechOutput(
            apiClient: apiClient,
            audioOutput: audioOutput,
            keychain: keychain
        )
        return (output, apiClient, audioOutput, keychain)
    }

    private func makeAudioResponse(statusCode: Int = 200, data: Data = Data([0x00, 0x01])) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: Self.dummyURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    // MARK: - Tests

    @Test("speak() sends correct URL, headers, and body")
    func testSpeakSendsCorrectRequest() async throws {
        let (output, apiClient, _, _) = makeOutput()
        apiClient.postResponses.append(makeAudioResponse())

        try await output.speak(text: "Hello JARVIS")

        #expect(apiClient.lastPostURL?.contains("api.deepgram.com/v1/speak") == true)
        #expect(apiClient.lastPostURL?.contains("linear16") == true)
        #expect(apiClient.lastPostURL?.contains("24000") == true)
        #expect(apiClient.lastPostHeaders?["Authorization"]?.hasPrefix("Token ") == true)
        #expect(apiClient.lastPostHeaders?["Content-Type"] == "application/json")

        if let body = apiClient.lastPostBody,
           let json = try? JSONDecoder().decode([String: String].self, from: body) {
            #expect(json["text"] == "Hello JARVIS")
        } else {
            Issue.record("Expected JSON body with text key")
        }
    }

    @Test("speak() with missing API key throws .apiKeyMissing")
    func testSpeakMissingKeyThrows() async throws {
        let (output, _, _, _) = makeOutput(apiKey: nil)

        do {
            try await output.speak(text: "hi")
            Issue.record("Expected throw")
        } catch let error as SpeechOutputError {
            #expect(error == .apiKeyMissing)
        }
    }

    @Test("speak() with HTTP error throws .synthesizeFailed")
    func testSpeakHTTPErrorThrows() async throws {
        let (output, apiClient, _, _) = makeOutput()
        apiClient.postError = APIClientError.httpError(statusCode: 401, body: nil)

        do {
            try await output.speak(text: "hello")
            Issue.record("Expected throw")
        } catch let error as SpeechOutputError {
            if case .synthesizeFailed = error { /* pass */ }
            else { Issue.record("Expected .synthesizeFailed, got \(error)") }
        }
    }

    @Test("speak() passes received audio data to audioOutput")
    func testSpeakPassesAudioData() async throws {
        let (output, apiClient, audioOutput, _) = makeOutput()
        let audioData = Data([0xAA, 0xBB, 0xCC, 0xDD])
        apiClient.postResponses.append(makeAudioResponse(data: audioData))

        try await output.speak(text: "play this")

        #expect(audioOutput.playedData == audioData)
        #expect(audioOutput.playedSampleRate == 24000)
    }

    @Test("speak() fires onStarted and onCompleted callbacks")
    func testSpeakCallbacks() async throws {
        let (output, apiClient, _, _) = makeOutput()
        apiClient.postResponses.append(makeAudioResponse())

        var startedFired = false
        var completedFired = false
        output.onStarted = { startedFired = true }
        output.onCompleted = { completedFired = true }

        try await output.speak(text: "test callbacks")

        #expect(startedFired == true)
        #expect(completedFired == true)
    }

    @Test("stop() sets isSpeaking to false")
    func testStopSetsisSpeakingFalse() async {
        let (output, _, _, _) = makeOutput()
        await output.stop()
        #expect(output.isSpeaking == false)
    }

    @Test("double speak() throws .alreadySpeaking")
    func testDoubleSpeakThrows() async throws {
        let (output, apiClient, _, _) = makeOutput()
        // Block the first speak so we can try a second
        apiClient.blockPost = true

        let firstTask = Task {
            try await output.speak(text: "first")
        }
        // Let first speak start
        try await Task.sleep(nanoseconds: 10_000_000)

        do {
            try await output.speak(text: "second")
            Issue.record("Expected .alreadySpeaking throw")
        } catch let error as SpeechOutputError {
            #expect(error == .alreadySpeaking)
        }

        firstTask.cancel()
    }

    @Test("text longer than 2000 chars is split into multiple API calls")
    func testLongTextSplit() async throws {
        let (output, apiClient, _, _) = makeOutput()
        // Build text >2000 chars with sentence boundaries
        let sentence = "This is a test sentence. "
        let longText = String(repeating: sentence, count: 100) // ~2500 chars
        let expectedCallCount = 2 // should be split into 2 chunks
        apiClient.postResponses.append(makeAudioResponse())
        apiClient.postResponses.append(makeAudioResponse())

        try await output.speak(text: longText)

        // Should have made multiple API calls
        #expect(apiClient.totalPostCallCount >= 2)
    }
}
