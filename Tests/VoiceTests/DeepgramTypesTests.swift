import Testing
import Foundation
@testable import JARVIS

@Suite("DeepgramTypes Tests")
struct DeepgramTypesTests {

    // MARK: - Fixtures

    private let interimResultJSON = """
    {
        "type": "Results",
        "channel_index": [0, 1],
        "duration": 1.5,
        "start": 0.0,
        "is_final": false,
        "speech_final": false,
        "channel": {
            "alternatives": [
                {
                    "transcript": "hello world",
                    "confidence": 0.98,
                    "words": [
                        { "word": "hello", "start": 0.0, "end": 0.5, "confidence": 0.99 },
                        { "word": "world", "start": 0.5, "end": 1.0, "confidence": 0.97 }
                    ]
                }
            ]
        }
    }
    """

    private let finalResultJSON = """
    {
        "type": "Results",
        "channel_index": [0, 1],
        "duration": 2.0,
        "start": 0.0,
        "is_final": true,
        "speech_final": true,
        "channel": {
            "alternatives": [
                { "transcript": "open safari", "confidence": 0.99, "words": null }
            ]
        }
    }
    """

    private let utteranceEndJSON = """
    { "type": "UtteranceEnd", "last_word_end": 2.5, "channel": [0] }
    """

    private let speechStartedJSON = """
    { "type": "SpeechStarted", "timestamp": 0.0, "channel": [0] }
    """

    private let metadataJSON = """
    { "type": "Metadata", "transaction_key": "abc", "request_id": "123" }
    """

    private let unknownJSON = """
    { "type": "FutureEvent", "data": "something" }
    """

    // MARK: - Tests

    @Test("Decode interim Results JSON")
    func testDecodeInterimResult() throws {
        let data = interimResultJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: data)

        #expect(response.type == "Results")
        #expect(response.isFinal == false)
        #expect(response.speechFinal == false)
        #expect(response.channel?.alternatives.first?.transcript == "hello world")
        #expect(response.channel?.alternatives.first?.confidence == 0.98)
        #expect(response.channel?.alternatives.first?.words?.count == 2)
    }

    @Test("Decode final Results JSON")
    func testDecodeFinalResult() throws {
        let data = finalResultJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(DeepgramTranscriptResponse.self, from: data)

        #expect(response.isFinal == true)
        #expect(response.speechFinal == true)
        #expect(response.channel?.alternatives.first?.transcript == "open safari")
    }

    @Test("parseMessage returns .utteranceEnd for UtteranceEnd type")
    func testParseUtteranceEnd() {
        let msg = DeepgramWebSocketTransport.parseMessage(utteranceEndJSON)
        #expect(msg == .utteranceEnd)
    }

    @Test("parseMessage returns .speechStarted for SpeechStarted type")
    func testParseSpeechStarted() {
        let msg = DeepgramWebSocketTransport.parseMessage(speechStartedJSON)
        #expect(msg == .speechStarted)
    }

    @Test("parseMessage returns .metadata for Metadata type")
    func testParseMetadata() {
        let msg = DeepgramWebSocketTransport.parseMessage(metadataJSON)
        #expect(msg == .metadata)
    }

    @Test("parseMessage returns .unknown for unrecognised type")
    func testParseUnknown() {
        let msg = DeepgramWebSocketTransport.parseMessage(unknownJSON)
        if case .unknown(let t) = msg {
            #expect(t == "FutureEvent")
        } else {
            Issue.record("Expected .unknown, got \(msg)")
        }
    }

    @Test("parseMessage returns .unknown for malformed JSON")
    func testParseMalformed() {
        let msg = DeepgramWebSocketTransport.parseMessage("not-json{{{")
        if case .unknown = msg {
            // pass
        } else {
            Issue.record("Expected .unknown for malformed JSON, got \(msg)")
        }
    }
}
