import AppKit

struct ClipboardWriteTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "clipboard_write",
            description: "Writes text to the system clipboard, replacing its current contents",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to write to the clipboard")
                    ])
                ]),
                "required": .array([.string("text")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let text) = arguments["text"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: text", isError: true)
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        Logger.tools.info("clipboard_write executed, wrote \(text.count) chars")
        return ToolResult(toolUseId: id, content: "Wrote \(text.count) characters to clipboard", isError: false)
    }
}
