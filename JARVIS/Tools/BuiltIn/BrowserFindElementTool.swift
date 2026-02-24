import Foundation

// MARK: - BrowserFindElementTool

/// Searches for an element in the current browser page by CSS selector or text content.
struct BrowserFindElementTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "browser_find_element",
        description: "Searches for an element in the current browser page. Provide a CSS selector, visible text, or both. At least one parameter is required.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "selector": .object([
                    "type": .string("string"),
                    "description": .string("CSS selector to find the element (e.g. \"#submit\", \".btn\", \"input[type='email']\").")
                ]),
                "text": .object([
                    "type": .string("string"),
                    "description": .string("Visible text content to search for in the page.")
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
        let selector: String?
        let text: String?

        if case .string(let s) = arguments["selector"] { selector = s } else { selector = nil }
        if case .string(let t) = arguments["text"] { text = t } else { text = nil }

        guard selector != nil || text != nil else {
            return ToolResult(
                toolUseId: id,
                content: "At least one of 'selector' or 'text' is required.",
                isError: true
            )
        }

        do {
            if let selector {
                let found = try await backend.findElement(selector: selector)
                if found {
                    // If text also specified, verify content matches
                    if let text {
                        let content = try await backend.evaluateJS(
                            "document.querySelector('\(selector)')?.textContent?.includes('\(text)') ?? false"
                        )
                        if content == "true" {
                            return ToolResult(toolUseId: id, content: "Element found: \(selector) contains '\(text)'", isError: false)
                        } else {
                            return ToolResult(toolUseId: id, content: "Element found: \(selector), but text '\(text)' not found in it.", isError: false)
                        }
                    }
                    return ToolResult(toolUseId: id, content: "Element found: \(selector)", isError: false)
                } else {
                    return ToolResult(toolUseId: id, content: "Element not found: \(selector)", isError: false)
                }
            } else if let text {
                // Text-only search: look through all elements
                let escapedText = text.replacingOccurrences(of: "'", with: "\\'")
                let js = "Array.from(document.querySelectorAll('*')).some(el => el.textContent && el.textContent.includes('\(escapedText)'))"
                let result = try await backend.evaluateJS(js)
                if result == "true" {
                    return ToolResult(toolUseId: id, content: "Text '\(text)' found on page.", isError: false)
                } else {
                    return ToolResult(toolUseId: id, content: "Text '\(text)' not found on page.", isError: false)
                }
            }
            return ToolResult(toolUseId: id, content: "No search criteria provided.", isError: true)
        } catch {
            Logger.browser.error("browser_find_element failed: \(error)")
            return ToolResult(toolUseId: id, content: "Find element failed: \(error.localizedDescription)", isError: true)
        }
    }
}
