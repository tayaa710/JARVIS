import Testing
import Foundation
@testable import JARVIS

@Suite("Anthropic Provider Tests")
struct AnthropicProviderTests {

    private func makeProvider(client: MockAPIClient) -> AnthropicProvider {
        AnthropicProvider(
            apiClient: client,
            apiKey: "test-api-key",
            model: "claude-opus-4-6",
            maxTokens: 1024,
            apiVersion: "2023-06-01"
        )
    }

    // MARK: - Request format

    @Test func testRequestFormatBasicText() async throws {
        let client = MockAPIClient()
        let fixture = try TestFixtures.load("text_response.json")
        client.enqueueJSONResponse(data: fixture)

        let provider = makeProvider(client: client)
        _ = try await provider.send(messages: [Message(role: .user, text: "Hello")], tools: [], system: nil)

        #expect(client.lastPostURL == "https://api.anthropic.com/v1/messages")
        let body = try JSONSerialization.jsonObject(with: client.lastPostBody!) as! [String: Any]
        #expect(body["model"] as? String == "claude-opus-4-6")
        #expect(body["max_tokens"] as? Int == 1024)
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        #expect(messages?.first?["role"] as? String == "user")
    }

    @Test func testRequestFormatWithSystemPrompt() async throws {
        let client = MockAPIClient()
        let fixture = try TestFixtures.load("text_response.json")
        client.enqueueJSONResponse(data: fixture)

        let provider = makeProvider(client: client)
        _ = try await provider.send(
            messages: [Message(role: .user, text: "Hi")],
            tools: [],
            system: "You are JARVIS."
        )

        let body = try JSONSerialization.jsonObject(with: client.lastPostBody!) as! [String: Any]
        #expect(body["system"] as? String == "You are JARVIS.")
    }

    @Test func testRequestFormatWithTools() async throws {
        let client = MockAPIClient()
        let fixture = try TestFixtures.load("tool_use_response.json")
        client.enqueueJSONResponse(data: fixture)

        let tool = ToolDefinition(
            name: "system_info",
            description: "Get system info",
            inputSchema: .object(["type": .string("object"), "properties": .object([:]), "required": .array([])])
        )
        let provider = makeProvider(client: client)
        _ = try await provider.send(messages: [Message(role: .user, text: "What OS?")], tools: [tool], system: nil)

        let body = try JSONSerialization.jsonObject(with: client.lastPostBody!) as! [String: Any]
        let tools = body["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?.first?["name"] as? String == "system_info")
        #expect(tools?.first?["input_schema"] != nil)
    }

    @Test func testRequestHeaders() async throws {
        let client = MockAPIClient()
        client.enqueueJSONResponse(data: try TestFixtures.load("text_response.json"))

        let provider = makeProvider(client: client)
        _ = try await provider.send(messages: [], tools: [], system: nil)

        let headers = client.lastPostHeaders!
        #expect(headers["x-api-key"] == "test-api-key")
        #expect(headers["anthropic-version"] == "2023-06-01")
        #expect(headers["content-type"] == "application/json")
    }

    // MARK: - Response parsing

    @Test func testResponseParsingTextOnly() async throws {
        let client = MockAPIClient()
        client.enqueueJSONResponse(data: try TestFixtures.load("text_response.json"))

        let provider = makeProvider(client: client)
        let response = try await provider.send(messages: [], tools: [], system: nil)

        #expect(response.id == "msg_test01")
        #expect(response.stopReason == .endTurn)
        guard case .text(let text) = response.content.first else {
            Issue.record("Expected text content"); return
        }
        #expect(text == "Hello! How can I help you?")
    }

    @Test func testResponseParsingToolUse() async throws {
        let client = MockAPIClient()
        client.enqueueJSONResponse(data: try TestFixtures.load("tool_use_response.json"))

        let provider = makeProvider(client: client)
        let response = try await provider.send(messages: [], tools: [], system: nil)

        #expect(response.stopReason == .toolUse)
        guard case .toolUse(let toolUse) = response.content.first else {
            Issue.record("Expected tool_use content"); return
        }
        #expect(toolUse.id == "toolu_test01")
        #expect(toolUse.name == "system_info")
    }

    @Test func testResponseParsingMixed() async throws {
        let client = MockAPIClient()
        client.enqueueJSONResponse(data: try TestFixtures.load("mixed_response.json"))

        let provider = makeProvider(client: client)
        let response = try await provider.send(messages: [], tools: [], system: nil)

        #expect(response.content.count == 2)
        guard case .text(let text) = response.content[0] else {
            Issue.record("Expected text first"); return
        }
        #expect(text == "Let me check that for you.")
        guard case .toolUse(let toolUse) = response.content[1] else {
            Issue.record("Expected tool_use second"); return
        }
        #expect(toolUse.name == "get_weather")
    }

    // MARK: - Error handling

    @Test func testError401Unauthorized() async throws {
        let client = MockAPIClient()
        client.postError = APIClientError.httpError(statusCode: 401, body: nil)

        let provider = makeProvider(client: client)
        await #expect(throws: AnthropicError.unauthorized) {
            _ = try await provider.send(messages: [], tools: [], system: nil)
        }
    }

    @Test func testError429RateLimited() async throws {
        let client = MockAPIClient()
        client.postError = APIClientError.httpError(statusCode: 429, body: nil)

        let provider = makeProvider(client: client)
        await #expect(throws: AnthropicError.rateLimited) {
            _ = try await provider.send(messages: [], tools: [], system: nil)
        }
    }

    @Test func testError500ServerError() async throws {
        let client = MockAPIClient()
        client.postError = APIClientError.httpError(statusCode: 500, body: nil)

        let provider = makeProvider(client: client)
        await #expect(throws: AnthropicError.serverError(500)) {
            _ = try await provider.send(messages: [], tools: [], system: nil)
        }
    }

    @Test func testErrorMalformedResponse() async throws {
        let client = MockAPIClient()
        client.enqueueJSONResponse(data: "not json at all".data(using: .utf8)!)

        let provider = makeProvider(client: client)
        do {
            _ = try await provider.send(messages: [], tools: [], system: nil)
            Issue.record("Expected invalidResponse error")
        } catch let error as AnthropicError {
            guard case .invalidResponse = error else {
                Issue.record("Expected .invalidResponse, got \(error)"); return
            }
        }
    }

    // MARK: - Abort

    @Test func testAbortCancelsInFlightRequest() async throws {
        let client = MockAPIClient()
        client.blockPost = true  // post() sleeps 60s until task cancellation

        let provider = makeProvider(client: client)

        let sendTask = Task<Response, Error> {
            try await provider.send(messages: [], tools: [], system: nil)
        }

        // Give the send task time to reach the blocking post() call.
        try await Task.sleep(for: .milliseconds(50))

        provider.abort()

        do {
            _ = try await sendTask.value
            Issue.record("Expected cancellation error")
        } catch AnthropicError.cancelled {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Streaming

    @Test func testStreamingTextDeltas() async throws {
        let client = MockAPIClient()
        let fixtureText = try TestFixtures.loadString("streaming_text.txt")
        client.enqueueFixtureStream(fixtureText)

        let provider = makeProvider(client: client)
        let stream = provider.sendStreaming(messages: [], tools: [], system: nil)

        var textDeltas: [String] = []
        var sawMessageStart = false
        var sawMessageStop = false

        for try await event in stream {
            switch event {
            case .messageStart: sawMessageStart = true
            case .textDelta(let t): textDeltas.append(t)
            case .messageStop: sawMessageStop = true
            default: break
            }
        }

        #expect(sawMessageStart)
        #expect(sawMessageStop)
        let joined = textDeltas.joined()
        #expect(joined == "Hello! How can I help you?")
    }

    @Test func testStreamingToolUseEvents() async throws {
        let client = MockAPIClient()
        let fixtureText = try TestFixtures.loadString("streaming_tool_use.txt")
        client.enqueueFixtureStream(fixtureText)

        let provider = makeProvider(client: client)
        let stream = provider.sendStreaming(messages: [], tools: [], system: nil)

        var toolUseStartEvents: [StreamEvent] = []

        for try await event in stream {
            if case .toolUseStart = event {
                toolUseStartEvents.append(event)
            }
        }

        #expect(toolUseStartEvents.count == 1)
        guard case .toolUseStart(let index, let toolUse) = toolUseStartEvents[0] else {
            Issue.record("Expected toolUseStart"); return
        }
        #expect(index == 1)
        #expect(toolUse.name == "system_info")
        #expect(toolUse.id == "toolu_stream01")
    }

    @Test func testStreamingMessageLifecycle() async throws {
        let client = MockAPIClient()
        client.enqueueFixtureStream(try TestFixtures.loadString("streaming_text.txt"))

        let provider = makeProvider(client: client)
        let stream = provider.sendStreaming(messages: [], tools: [], system: nil)

        var events: [StreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        // First event should be messageStart, last should be messageStop.
        guard case .messageStart(let id, _) = events.first else {
            Issue.record("First event should be messageStart"); return
        }
        #expect(id == "msg_stream01")

        guard case .messageStop = events.last else {
            Issue.record("Last event should be messageStop"); return
        }
    }
}
