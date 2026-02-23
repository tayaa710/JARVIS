import AppKit

struct ClipboardReadTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "clipboard_read",
            description: "Returns the current text content of the system clipboard",
            inputSchema: .object(["type": .string("object")])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let content = NSPasteboard.general.string(forType: .string) ?? "Clipboard is empty"
        Logger.tools.info("clipboard_read executed")
        return ToolResult(toolUseId: id, content: content, isError: false)
    }
}
