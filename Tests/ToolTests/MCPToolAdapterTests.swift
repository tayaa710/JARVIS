import Testing
import Foundation
@testable import JARVIS

@Suite("MCPToolAdapter Tests")
struct MCPToolAdapterTests {

    private func makeTool(name: String = "read_file", description: String? = "Reads a file") -> MCPTool {
        MCPTool(
            name: name,
            description: description,
            inputSchema: .object(["type": .string("object"), "properties": .object([:])])
        )
    }

    private func makeAdapter(
        toolName: String = "read_file",
        serverName: String = "filesystem",
        description: String? = "Reads a file",
        client: MockMCPClient = MockMCPClient()
    ) -> MCPToolAdapter {
        MCPToolAdapter(mcpTool: makeTool(name: toolName, description: description), client: client, serverName: serverName)
    }

    // MARK: - Definition Mapping

    @Test func definitionNameIsPrefixed() {
        let adapter = makeAdapter(toolName: "read_file", serverName: "fs")
        #expect(adapter.definition.name == "mcp__fs__read_file")
    }

    @Test func definitionDescriptionFromTool() {
        let adapter = makeAdapter(description: "Read a file from disk")
        #expect(adapter.definition.description == "Read a file from disk")
    }

    @Test func definitionDescriptionFallsBackWhenNil() {
        let adapter = makeAdapter(serverName: "myserver", description: nil)
        #expect(adapter.definition.description == "MCP tool from myserver")
    }

    @Test func definitionSchemaPassedThrough() {
        let adapter = makeAdapter()
        if case .object(let schema) = adapter.definition.inputSchema,
           case .string(let type) = schema["type"] {
            #expect(type == "object")
        } else {
            Issue.record("Expected object schema")
        }
    }

    // MARK: - Risk Level

    @Test func riskLevelIsCaution() {
        let adapter = makeAdapter()
        #expect(adapter.riskLevel == .caution)
    }

    // MARK: - Execute

    @Test func executeSuccessReturnsCorrectContent() async throws {
        let client = MockMCPClient()
        client.callToolResult = MCPToolCallResult(
            content: [.text("file contents here")],
            isError: nil
        )
        let adapter = MCPToolAdapter(mcpTool: makeTool(), client: client, serverName: "fs")
        let result = try await adapter.execute(id: "tu_1", arguments: ["path": .string("/tmp/test.txt")])
        #expect(result.toolUseId == "tu_1")
        #expect(result.content == "file contents here")
        #expect(result.isError == false)
    }

    @Test func executeWithIsErrorReturnsErrorResult() async throws {
        let client = MockMCPClient()
        client.callToolResult = MCPToolCallResult(
            content: [.text("Permission denied")],
            isError: true
        )
        let adapter = MCPToolAdapter(mcpTool: makeTool(), client: client, serverName: "fs")
        let result = try await adapter.execute(id: "tu_2", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func executeJoinsMultipleContentItemsWithNewline() async throws {
        let client = MockMCPClient()
        client.callToolResult = MCPToolCallResult(
            content: [.text("Line 1"), .text("Line 2"), .text("Line 3")],
            isError: nil
        )
        let adapter = MCPToolAdapter(mcpTool: makeTool(), client: client, serverName: "fs")
        let result = try await adapter.execute(id: "tu_3", arguments: [:])
        #expect(result.content == "Line 1\nLine 2\nLine 3")
    }

    @Test func executeWithNoTextContentReturnsPlaceholder() async throws {
        let client = MockMCPClient()
        client.callToolResult = MCPToolCallResult(
            content: [.image(data: "abc", mimeType: "image/png")],
            isError: nil
        )
        let adapter = MCPToolAdapter(mcpTool: makeTool(), client: client, serverName: "fs")
        let result = try await adapter.execute(id: "tu_4", arguments: [:])
        #expect(result.content == "(no output)")
    }

    @Test func executePassesCorrectToolNameToClient() async throws {
        let client = MockMCPClient()
        client.callToolResult = MCPToolCallResult(content: [.text("ok")], isError: nil)
        let adapter = MCPToolAdapter(mcpTool: makeTool(name: "my_tool"), client: client, serverName: "srv")
        _ = try await adapter.execute(id: "tu_5", arguments: [:])
        #expect(client.lastCallToolName == "my_tool")
    }

    @Test func executeThrowsOnClientError() async throws {
        let client = MockMCPClient()
        client.callToolError = MCPError.timeout
        let adapter = MCPToolAdapter(mcpTool: makeTool(), client: client, serverName: "fs")
        await #expect(throws: MCPError.timeout) {
            _ = try await adapter.execute(id: "tu_6", arguments: [:])
        }
    }
}
