import Foundation

// MARK: - BrowserGetURLTool

/// Returns the URL of the current browser tab.
struct BrowserGetURLTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_get_url",
        description: "Returns the URL of the current browser tab.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([])
        ])
    )

    let riskLevel: RiskLevel = .safe

    private let backend: any BrowserBackend

    init(backend: any BrowserBackend) {
        self.backend = backend
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        do {
            let url = try await backend.getURL()
            Logger.browser.info("browser_get_url: \(url)")
            return ToolResult(toolUseId: id, content: url, isError: false)
        } catch {
            Logger.browser.error("browser_get_url failed: \(error)")
            return ToolResult(toolUseId: id, content: "Failed to get URL: \(error.localizedDescription)", isError: true)
        }
    }
}
