import Foundation

// MARK: - BrowserClickTool

/// Clicks a DOM element in the current browser page matching a CSS selector.
struct BrowserClickTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_click",
        description: "Clicks a DOM element in the current browser page matching the given CSS selector. Prefer this over mouse_click with pixel coordinates for web page elements.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "selector": .object([
                    "type": .string("string"),
                    "description": .string("CSS selector of the element to click (e.g. \"button#submit\", \".btn-primary\").")
                ])
            ]),
            "required": .array([.string("selector")])
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
        do {
            try await backend.clickElement(selector: selector)
            Logger.browser.info("browser_click: \(selector)")
            return ToolResult(toolUseId: id, content: "Clicked element matching '\(selector)'", isError: false)
        } catch {
            Logger.browser.error("browser_click failed: \(error)")
            return ToolResult(toolUseId: id, content: "Click failed: \(error.localizedDescription)", isError: true)
        }
    }
}
