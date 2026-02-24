import Foundation

// MARK: - BrowserGetTextTool

/// Returns the visible text content of the current browser page.
struct BrowserGetTextTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_get_text",
        description: "Returns the visible text content of the current browser page. Prefer this over screenshot + vision_analyze for reading page content. Fast and returns structured text.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "max_length": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of characters to return. Defaults to 10000.")
                ])
            ]),
            "required": .array([])
        ])
    )

    let riskLevel: RiskLevel = .safe

    private let backend: any BrowserBackend

    init(backend: any BrowserBackend) {
        self.backend = backend
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let maxLength: Int
        if case .number(let n) = arguments["max_length"] {
            maxLength = Int(n)
        } else {
            maxLength = 10_000
        }

        do {
            var text = try await backend.getText()
            let truncated = text.count > maxLength
            if truncated {
                let index = text.index(text.startIndex, offsetBy: maxLength)
                text = String(text[..<index]) + "... (truncated)"
            }
            Logger.browser.info("browser_get_text: \(text.count) chars (truncated=\(truncated))")
            return ToolResult(toolUseId: id, content: text, isError: false)
        } catch {
            Logger.browser.error("browser_get_text failed: \(error)")
            return ToolResult(toolUseId: id, content: "Failed to get page text: \(error.localizedDescription)", isError: true)
        }
    }
}
