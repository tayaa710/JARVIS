import Foundation

// MARK: - BrowserNavigateTool

/// Navigates the frontmost browser tab to the given URL.
struct BrowserNavigateTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_navigate",
        description: "Navigates the current browser tab to a URL. Works with Safari and Chromium browsers (Chrome, Arc, Edge, Brave). Chrome must be launched with --remote-debugging-port=9222.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("The URL to navigate to (e.g. \"https://example.com\").")
                ])
            ]),
            "required": .array([.string("url")])
        ])
    )

    let riskLevel: RiskLevel = .caution

    private let backend: any BrowserBackend

    init(backend: any BrowserBackend) {
        self.backend = backend
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let url) = arguments["url"] else {
            return ToolResult(toolUseId: id, content: "Missing required parameter: url", isError: true)
        }
        do {
            try await backend.navigate(url: url)
            Logger.browser.info("browser_navigate: \(url)")
            return ToolResult(toolUseId: id, content: "Navigated to \(url)", isError: false)
        } catch {
            Logger.browser.error("browser_navigate failed: \(error)")
            return ToolResult(toolUseId: id, content: "Navigation failed: \(error.localizedDescription)", isError: true)
        }
    }
}
