import Testing
import Foundation
@testable import JARVIS

@Suite("MCPTypes Tests")
struct MCPTypesTests {

    // MARK: - JSONRPCRequest

    @Test func jsonRPCRequestEncodesCorrectly() throws {
        let request = JSONRPCRequest(id: 1, method: "tools/list", params: nil)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? Int == 1)
        #expect(json["method"] as? String == "tools/list")
        // no params key when nil
        #expect(json["params"] == nil)
    }

    @Test func jsonRPCRequestWithParamsEncodesCorrectly() throws {
        let params = JSONValue.object(["key": .string("value")])
        let request = JSONRPCRequest(id: 2, method: "tools/call", params: params)
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["id"] as? Int == 2)
        #expect(json["method"] as? String == "tools/call")
        #expect(json["params"] != nil)
    }

    // MARK: - JSONRPCResponse

    @Test func jsonRPCResponseDecodesSuccessResult() throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"result":{"status":"ok"}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: json)
        #expect(response.jsonrpc == "2.0")
        #expect(response.id == 1)
        #expect(response.result != nil)
        #expect(response.error == nil)
    }

    @Test func jsonRPCResponseDecodesErrorResponse() throws {
        let json = """
        {"jsonrpc":"2.0","id":2,"error":{"code":-32601,"message":"Method not found"}}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: json)
        #expect(response.id == 2)
        #expect(response.error != nil)
        #expect(response.error?.code == -32601)
        #expect(response.error?.message == "Method not found")
        #expect(response.result == nil)
    }

    // MARK: - JSONRPCNotification

    @Test func jsonRPCNotificationEncodesWithoutId() throws {
        let notification = JSONRPCNotification(method: "notifications/initialized", params: nil)
        let data = try JSONEncoder().encode(notification)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["jsonrpc"] as? String == "2.0")
        #expect(json["method"] as? String == "notifications/initialized")
        #expect(json["id"] == nil)
    }

    // MARK: - MCPTool

    @Test func mcpToolDecodesFromToolsListResponse() throws {
        let json = """
        {
          "name": "read_file",
          "description": "Read a file from disk",
          "inputSchema": {
            "type": "object",
            "properties": {
              "path": {"type": "string"}
            },
            "required": ["path"]
          }
        }
        """.data(using: .utf8)!
        let tool = try JSONDecoder().decode(MCPTool.self, from: json)
        #expect(tool.name == "read_file")
        #expect(tool.description == "Read a file from disk")
        if case .object(let schema) = tool.inputSchema,
           case .string(let type) = schema["type"] {
            #expect(type == "object")
        } else {
            Issue.record("Expected object schema")
        }
    }

    // MARK: - MCPToolCallResult

    @Test func mcpToolCallResultDecodesTextContent() throws {
        let json = """
        {"content":[{"type":"text","text":"Hello world"}],"isError":false}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(MCPToolCallResult.self, from: json)
        #expect(result.content.count == 1)
        if case .text(let t) = result.content[0] {
            #expect(t == "Hello world")
        } else {
            Issue.record("Expected text content")
        }
        #expect(result.isError == false)
    }

    @Test func mcpToolCallResultDecodesMixedContent() throws {
        let json = """
        {
          "content": [
            {"type":"text","text":"Caption"},
            {"type":"image","data":"abc123","mimeType":"image/png"}
          ]
        }
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(MCPToolCallResult.self, from: json)
        #expect(result.content.count == 2)
        if case .text(let t) = result.content[0] {
            #expect(t == "Caption")
        } else {
            Issue.record("Expected text at index 0")
        }
        if case .image(let data, let mime) = result.content[1] {
            #expect(data == "abc123")
            #expect(mime == "image/png")
        } else {
            Issue.record("Expected image at index 1")
        }
    }

    // MARK: - MCPContent

    @Test func mcpContentDecodesTextType() throws {
        let json = """
        {"type":"text","text":"Hello"}
        """.data(using: .utf8)!
        let content = try JSONDecoder().decode(MCPContent.self, from: json)
        if case .text(let t) = content {
            #expect(t == "Hello")
        } else {
            Issue.record("Expected .text")
        }
    }

    @Test func mcpContentDecodesImageType() throws {
        let json = """
        {"type":"image","data":"base64data","mimeType":"image/jpeg"}
        """.data(using: .utf8)!
        let content = try JSONDecoder().decode(MCPContent.self, from: json)
        if case .image(let data, let mime) = content {
            #expect(data == "base64data")
            #expect(mime == "image/jpeg")
        } else {
            Issue.record("Expected .image")
        }
    }

    // MARK: - Round-trip

    @Test func jsonRPCRequestRoundTrip() throws {
        let original = JSONRPCRequest(id: 42, method: "initialize", params: .object(["version": .string("2025-11-25")]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONRPCRequest.self, from: data)
        #expect(decoded.jsonrpc == original.jsonrpc)
        #expect(decoded.id == original.id)
        #expect(decoded.method == original.method)
    }
}
