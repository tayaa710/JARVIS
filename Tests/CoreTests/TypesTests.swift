import Testing
import Foundation
@testable import JARVIS

@Suite("Types Tests")
struct TypesTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Message encoding

    @Test func testMessageWithTextContentEncodesToStringShorthand() throws {
        let message = Message(role: .user, text: "Hello JARVIS")
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["role"] as? String == "user")
        // Single text block should encode as plain string shorthand.
        #expect(json["content"] as? String == "Hello JARVIS")
    }

    @Test func testMessageWithMultipleBlocksEncodesToArray() throws {
        let result = ToolResult(toolUseId: "tu_1", content: "result text", isError: false)
        let message = Message(role: .user, content: [
            .text("Here is the result:"),
            .toolResult(result)
        ])
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["role"] as? String == "user")
        let contentArray = json["content"] as? [[String: Any]]
        #expect(contentArray?.count == 2)
    }

    @Test func testMessageWithToolResultEncodesCorrectly() throws {
        let result = ToolResult(toolUseId: "toolu_abc", content: "65 degrees", isError: false)
        let message = Message(role: .user, content: [.toolResult(result)])
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let blocks = json["content"] as! [[String: Any]]
        let block = blocks[0]

        #expect(block["type"] as? String == "tool_result")
        #expect(block["tool_use_id"] as? String == "toolu_abc")
        #expect(block["content"] as? String == "65 degrees")
        #expect(block["is_error"] as? Bool == false)
    }

    // MARK: - ContentBlock encoding

    @Test func testContentBlockTextEncodes() throws {
        let block = ContentBlock.text("Hello!")
        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "text")
        #expect(json["text"] as? String == "Hello!")
    }

    @Test func testContentBlockToolUseEncodes() throws {
        let toolUse = ToolUse(id: "toolu_01", name: "system_info", input: [:])
        let block = ContentBlock.toolUse(toolUse)
        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "tool_use")
        #expect(json["id"] as? String == "toolu_01")
        #expect(json["name"] as? String == "system_info")
        #expect(json["input"] as? [String: Any] != nil)
    }

    @Test func testContentBlockToolResultEncodes() throws {
        let result = ToolResult(toolUseId: "toolu_02", content: "done", isError: false)
        let block = ContentBlock.toolResult(result)
        let data = try encoder.encode(block)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["type"] as? String == "tool_result")
        #expect(json["tool_use_id"] as? String == "toolu_02")
        #expect(json["content"] as? String == "done")
        #expect(json["is_error"] as? Bool == false)
    }

    // MARK: - Response decoding

    @Test func testResponseDecodesFromTextOnlyAPIJSON() throws {
        let json = """
        {
            "id": "msg_test01",
            "type": "message",
            "role": "assistant",
            "content": [{"type": "text", "text": "Hello! How can I help you?"}],
            "model": "claude-opus-4-6",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {"input_tokens": 12, "output_tokens": 8}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(Response.self, from: json)
        #expect(response.id == "msg_test01")
        #expect(response.model == "claude-opus-4-6")
        #expect(response.stopReason == .endTurn)
        #expect(response.usage.inputTokens == 12)
        #expect(response.usage.outputTokens == 8)
        guard case .text(let text) = response.content.first else {
            Issue.record("Expected text content block"); return
        }
        #expect(text == "Hello! How can I help you?")
    }

    @Test func testResponseDecodesFromToolUseAPIJSON() throws {
        let json = """
        {
            "id": "msg_test02",
            "type": "message",
            "role": "assistant",
            "content": [{"type": "tool_use", "id": "toolu_test01", "name": "system_info", "input": {}}],
            "model": "claude-opus-4-6",
            "stop_reason": "tool_use",
            "stop_sequence": null,
            "usage": {"input_tokens": 100, "output_tokens": 50}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(Response.self, from: json)
        #expect(response.stopReason == .toolUse)
        guard case .toolUse(let toolUse) = response.content.first else {
            Issue.record("Expected tool_use content block"); return
        }
        #expect(toolUse.id == "toolu_test01")
        #expect(toolUse.name == "system_info")
        #expect(toolUse.input.isEmpty)
    }

    @Test func testResponseDecodesFromMixedAPIJSON() throws {
        let json = """
        {
            "id": "msg_test03",
            "type": "message",
            "role": "assistant",
            "content": [
                {"type": "text", "text": "Let me check that for you."},
                {"type": "tool_use", "id": "toolu_test02", "name": "get_weather",
                 "input": {"location": "San Francisco, CA"}}
            ],
            "model": "claude-opus-4-6",
            "stop_reason": "tool_use",
            "stop_sequence": null,
            "usage": {"input_tokens": 80, "output_tokens": 60}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(Response.self, from: json)
        #expect(response.content.count == 2)
        guard case .text(let text) = response.content[0] else {
            Issue.record("Expected text block first"); return
        }
        #expect(text == "Let me check that for you.")
        guard case .toolUse(let toolUse) = response.content[1] else {
            Issue.record("Expected tool_use block second"); return
        }
        #expect(toolUse.input["location"] == .string("San Francisco, CA"))
    }

    // MARK: - ToolDefinition encoding

    @Test func testToolDefinitionEncodesToAnthropicFormat() throws {
        let schema = JSONValue.object([
            "type": .string("object"),
            "properties": .object([
                "location": .object(["type": .string("string")])
            ]),
            "required": .array([.string("location")])
        ])
        let tool = ToolDefinition(name: "get_weather", description: "Get weather", inputSchema: schema)
        let data = try encoder.encode(tool)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["name"] as? String == "get_weather")
        #expect(json["description"] as? String == "Get weather")
        // Must use snake_case key.
        #expect(json["input_schema"] != nil)
        #expect(json["inputSchema"] == nil)
    }

    // MARK: - Usage decoding

    @Test func testUsageDecodesIgnoringExtraFields() throws {
        let json = """
        {
            "input_tokens": 10,
            "output_tokens": 5,
            "cache_creation_input_tokens": 100,
            "cache_read_input_tokens": 50
        }
        """.data(using: .utf8)!

        let usage = try decoder.decode(Usage.self, from: json)
        #expect(usage.inputTokens == 10)
        #expect(usage.outputTokens == 5)
    }

    // MARK: - JSONValue round-trip

    @Test func testJSONValueRoundTripForNestedStructures() throws {
        let original = JSONValue.object([
            "name": .string("test"),
            "count": .number(42),
            "active": .bool(true),
            "nothing": .null,
            "tags": .array([.string("a"), .string("b")]),
            "meta": .object(["key": .string("value")])
        ])
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }
}
