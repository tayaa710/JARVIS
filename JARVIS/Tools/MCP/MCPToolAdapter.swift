import Foundation

// MARK: - MCPToolAdapter

/// Wraps a single MCP tool (discovered via tools/list) as a ToolExecutor,
/// enabling it to be registered in the existing ToolRegistry.
///
/// Tool names are namespaced as `mcp__<serverName>__<toolName>` to avoid
/// collisions with built-in tools.
struct MCPToolAdapter: ToolExecutor {

    // MARK: - Init

    init(mcpTool: MCPTool, client: any MCPClientProtocol, serverName: String) {
        self.mcpTool = mcpTool
        self.client = client
        self.serverName = serverName
    }

    // MARK: - Private

    private let mcpTool: MCPTool
    private let client: any MCPClientProtocol
    private let serverName: String

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "mcp__\(serverName)__\(mcpTool.name)",
            description: mcpTool.description ?? "MCP tool from \(serverName)",
            inputSchema: mcpTool.inputSchema
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let mcpResult = try await client.callTool(name: mcpTool.name, arguments: arguments)

        let text = mcpResult.content
            .compactMap { item -> String? in
                if case .text(let t) = item { return t }
                return nil
            }
            .joined(separator: "\n")

        return ToolResult(
            toolUseId: id,
            content: text.isEmpty ? "(no output)" : text,
            isError: mcpResult.isError ?? false
        )
    }
}
