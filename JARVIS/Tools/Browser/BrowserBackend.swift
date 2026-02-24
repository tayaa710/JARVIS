import Foundation

// MARK: - BrowserBackend

/// High-level browser control interface.
/// Implemented by AppleScriptBackend (Safari) and exposed via BrowserRouter
/// (which wraps CDPBackendProtocol for Chromium browsers).
public protocol BrowserBackend: Sendable {
    /// Navigates the current tab to the given URL.
    func navigate(url: String) async throws

    /// Returns the URL of the current tab.
    func getURL() async throws -> String

    /// Returns the text content of the current page.
    func getText() async throws -> String

    /// Returns true if a DOM element matching the CSS selector exists.
    func findElement(selector: String) async throws -> Bool

    /// Clicks the DOM element matching the CSS selector.
    func clickElement(selector: String) async throws

    /// Types text into the DOM element matching the CSS selector.
    func typeInElement(selector: String, text: String) async throws

    /// Evaluates a JavaScript expression and returns the result as a string.
    func evaluateJS(_ expression: String) async throws -> String
}
