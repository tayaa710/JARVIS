import Testing
import Foundation
@testable import JARVIS

@Suite("Browser Tool Tests")
struct BrowserToolTests {

    // MARK: - Helpers

    private func makeBackend() -> MockBrowserBackend { MockBrowserBackend() }

    // =========================================================================
    // MARK: - BrowserNavigateTool
    // =========================================================================

    @Test("browser_navigate: valid URL calls backend and returns success")
    func navigateValidArgs() async throws {
        let backend = makeBackend()
        let tool = BrowserNavigateTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["url": .string("https://example.com")])
        #expect(!result.isError)
        #expect(result.content.contains("https://example.com"))
        #expect(backend.navigateCallCount == 1)
        #expect(backend.lastNavigateURL == "https://example.com")
    }

    @Test("browser_navigate: missing url returns error")
    func navigateMissingURL() async throws {
        let tool = BrowserNavigateTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
        #expect(result.content.contains("url"))
    }

    @Test("browser_navigate: backend error returns error result")
    func navigateBackendError() async throws {
        let backend = makeBackend()
        backend.navigateShouldThrow = BrowserError.navigationFailed("DNS failed")
        let tool = BrowserNavigateTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["url": .string("https://bad.example")])
        #expect(result.isError)
        #expect(result.content.contains("DNS failed") || result.content.contains("failed"))
    }

    @Test("browser_navigate: risk level is caution")
    func navigateRiskLevel() {
        let tool = BrowserNavigateTool(backend: makeBackend())
        #expect(tool.riskLevel == .caution)
    }

    @Test("browser_navigate: definition has correct name")
    func navigateDefinition() {
        let tool = BrowserNavigateTool(backend: makeBackend())
        #expect(tool.definition.name == "browser_navigate")
    }

    @Test("browser_navigate: encodes URL in result message")
    func navigateResultIncludesURL() async throws {
        let tool = BrowserNavigateTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: ["url": .string("https://swift.org")])
        #expect(result.content.contains("swift.org"))
    }

    // =========================================================================
    // MARK: - BrowserGetURLTool
    // =========================================================================

    @Test("browser_get_url: calls backend and returns URL")
    func getURLValidArgs() async throws {
        let backend = makeBackend()
        backend.getURLResult = "https://apple.com"
        let tool = BrowserGetURLTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(!result.isError)
        #expect(result.content == "https://apple.com")
        #expect(backend.getURLCallCount == 1)
    }

    @Test("browser_get_url: no required params (empty args succeeds)")
    func getURLNoParams() async throws {
        let tool = BrowserGetURLTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(!result.isError)
    }

    @Test("browser_get_url: backend error returns error result")
    func getURLBackendError() async throws {
        let backend = makeBackend()
        backend.getURLShouldThrow = BrowserError.scriptFailed("Safari not responding")
        let tool = BrowserGetURLTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
    }

    @Test("browser_get_url: risk level is safe")
    func getURLRiskLevel() {
        #expect(BrowserGetURLTool(backend: makeBackend()).riskLevel == .safe)
    }

    @Test("browser_get_url: definition has correct name")
    func getURLDefinition() {
        #expect(BrowserGetURLTool(backend: makeBackend()).definition.name == "browser_get_url")
    }

    @Test("browser_get_url: returns exact URL string from backend")
    func getURLExactString() async throws {
        let backend = makeBackend()
        backend.getURLResult = "https://github.com/apple/swift"
        let tool = BrowserGetURLTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.content == "https://github.com/apple/swift")
    }

    // =========================================================================
    // MARK: - BrowserGetTextTool
    // =========================================================================

    @Test("browser_get_text: returns page text")
    func getTextValidArgs() async throws {
        let backend = makeBackend()
        backend.getTextResult = "Hello, world!"
        let tool = BrowserGetTextTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(!result.isError)
        #expect(result.content.contains("Hello, world!"))
        #expect(backend.getTextCallCount == 1)
    }

    @Test("browser_get_text: truncates text to max_length")
    func getTextTruncation() async throws {
        let backend = makeBackend()
        backend.getTextResult = String(repeating: "A", count: 500)
        let tool = BrowserGetTextTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["max_length": .number(100)])
        #expect(!result.isError)
        #expect(result.content.count <= 130) // 100 chars + "... (truncated)"
        #expect(result.content.contains("truncated"))
    }

    @Test("browser_get_text: backend error returns error result")
    func getTextBackendError() async throws {
        let backend = makeBackend()
        backend.getTextShouldThrow = BrowserError.scriptFailed("timeout")
        let tool = BrowserGetTextTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
    }

    @Test("browser_get_text: risk level is safe")
    func getTextRiskLevel() {
        #expect(BrowserGetTextTool(backend: makeBackend()).riskLevel == .safe)
    }

    @Test("browser_get_text: definition has correct name")
    func getTextDefinition() {
        #expect(BrowserGetTextTool(backend: makeBackend()).definition.name == "browser_get_text")
    }

    @Test("browser_get_text: no truncation when text is short")
    func getTextNoTruncation() async throws {
        let backend = makeBackend()
        backend.getTextResult = "Short text"
        let tool = BrowserGetTextTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(!result.isError)
        #expect(!result.content.contains("truncated"))
    }

    // =========================================================================
    // MARK: - BrowserFindElementTool
    // =========================================================================

    @Test("browser_find_element: finds element by CSS selector")
    func findElementBySelector() async throws {
        let backend = makeBackend()
        backend.findElementResult = true
        let tool = BrowserFindElementTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string("#submit")])
        #expect(!result.isError)
        #expect(result.content.contains("found") || result.content.contains("Found"))
        #expect(backend.findElementCallCount == 1)
        #expect(backend.lastFindElementSelector == "#submit")
    }

    @Test("browser_find_element: missing selector and text returns error")
    func findElementMissingArgs() async throws {
        let tool = BrowserFindElementTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
    }

    @Test("browser_find_element: backend error returns error result")
    func findElementBackendError() async throws {
        let backend = makeBackend()
        backend.findElementShouldThrow = BrowserError.scriptFailed("JS error")
        let tool = BrowserFindElementTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string(".btn")])
        #expect(result.isError)
    }

    @Test("browser_find_element: risk level is safe")
    func findElementRiskLevel() {
        #expect(BrowserFindElementTool(backend: makeBackend()).riskLevel == .safe)
    }

    @Test("browser_find_element: definition has correct name")
    func findElementDefinition() {
        #expect(BrowserFindElementTool(backend: makeBackend()).definition.name == "browser_find_element")
    }

    @Test("browser_find_element: text search uses evaluateJS")
    func findElementTextSearch() async throws {
        let backend = makeBackend()
        backend.evaluateJSResult = "true"
        let tool = BrowserFindElementTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("Submit")])
        #expect(!result.isError)
        #expect(backend.evaluateJSCallCount == 1)
        #expect(backend.lastEvaluateJSExpression?.contains("Submit") == true)
    }

    // =========================================================================
    // MARK: - BrowserClickTool
    // =========================================================================

    @Test("browser_click: clicks element matching selector")
    func clickValidArgs() async throws {
        let backend = makeBackend()
        let tool = BrowserClickTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string("button#submit")])
        #expect(!result.isError)
        #expect(result.content.contains("button#submit"))
        #expect(backend.clickElementCallCount == 1)
        #expect(backend.lastClickElementSelector == "button#submit")
    }

    @Test("browser_click: missing selector returns error")
    func clickMissingSelector() async throws {
        let tool = BrowserClickTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: [:])
        #expect(result.isError)
    }

    @Test("browser_click: backend error returns error result")
    func clickBackendError() async throws {
        let backend = makeBackend()
        backend.clickElementShouldThrow = BrowserError.scriptFailed("Element not found")
        let tool = BrowserClickTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string(".btn")])
        #expect(result.isError)
    }

    @Test("browser_click: risk level is caution")
    func clickRiskLevel() {
        #expect(BrowserClickTool(backend: makeBackend()).riskLevel == .caution)
    }

    @Test("browser_click: definition has correct name")
    func clickDefinition() {
        #expect(BrowserClickTool(backend: makeBackend()).definition.name == "browser_click")
    }

    @Test("browser_click: result mentions the selector")
    func clickResultMentionsSelector() async throws {
        let tool = BrowserClickTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string("a.link")])
        #expect(result.content.contains("a.link"))
    }

    // =========================================================================
    // MARK: - BrowserTypeTool
    // =========================================================================

    @Test("browser_type: types text into element")
    func typeValidArgs() async throws {
        let backend = makeBackend()
        let tool = BrowserTypeTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [
            "selector": .string("input#email"),
            "text": .string("user@example.com")
        ])
        #expect(!result.isError)
        #expect(result.content.contains("user@example.com"))
        #expect(backend.typeInElementCallCount == 1)
        #expect(backend.lastTypeInElementSelector == "input#email")
        #expect(backend.lastTypeInElementText == "user@example.com")
    }

    @Test("browser_type: missing selector returns error")
    func typeMissingSelector() async throws {
        let tool = BrowserTypeTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: ["text": .string("hello")])
        #expect(result.isError)
    }

    @Test("browser_type: missing text returns error")
    func typeMissingText() async throws {
        let tool = BrowserTypeTool(backend: makeBackend())
        let result = try await tool.execute(id: "t1", arguments: ["selector": .string("input")])
        #expect(result.isError)
    }

    @Test("browser_type: backend error returns error result")
    func typeBackendError() async throws {
        let backend = makeBackend()
        backend.typeInElementShouldThrow = BrowserError.scriptFailed("Element not found")
        let tool = BrowserTypeTool(backend: backend)
        let result = try await tool.execute(id: "t1", arguments: [
            "selector": .string("input"),
            "text": .string("hello")
        ])
        #expect(result.isError)
    }

    @Test("browser_type: risk level is caution")
    func typeRiskLevel() {
        #expect(BrowserTypeTool(backend: makeBackend()).riskLevel == .caution)
    }

    @Test("browser_type: definition has correct name")
    func typeDefinition() {
        #expect(BrowserTypeTool(backend: makeBackend()).definition.name == "browser_type")
    }
}
