import Foundation

// MARK: - BrowserTypeTool

/// Types text into a DOM element in the current browser page.
struct BrowserTypeTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_type",
        description: "Types text into a DOM element in the current browser page matching the given CSS selector. Sets the element's value and dispatches input/change events.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "selector": .object([
                    "type": .string("string"),
                    "description": .string("CSS selector of the element to type into (e.g. \"input#email\", \"textarea.message\").")
                ]),
                "text": .object([
                    "type": .string("string"),
                    "description": .string("The text to type into the element.")
                ])
            ]),
            "required": .array([.string("selector"), .string("text")])
        ])
    )

    let riskLevel: RiskLevel = .caution

    private let backend: any BrowserBackend

    init(backend: any BrowserBackend) {
        self.backend = backend
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let selector) = arguments["selector"] else {
            return ToolResult(toolUseId: id, content: "Missing required parameter: selector", isError: true)
        }
        guard case .string(let text) = arguments["text"] else {
            return ToolResult(toolUseId: id, content: "Missing required parameter: text", isError: true)
        }
        do {
            try await backend.typeInElement(selector: selector, text: text)
            Logger.browser.info("browser_type: typed into \(selector)")
            return ToolResult(toolUseId: id, content: "Typed '\(text)' into element matching '\(selector)'", isError: false)
        } catch {
            Logger.browser.error("browser_type failed: \(error)")
            return ToolResult(toolUseId: id, content: "Type failed: \(error.localizedDescription)", isError: true)
        }
    }
}
