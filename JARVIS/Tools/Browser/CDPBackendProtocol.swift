// MARK: - CDPBackendProtocol

/// High-level API for controlling a Chromium-family browser via Chrome DevTools Protocol.
/// M015 browser tools depend on this protocol — never on the concrete implementation.
public protocol CDPBackendProtocol: Sendable {
    /// Connects to the browser's CDP endpoint on the given port (default: 9222).
    func connect(port: Int) async throws

    /// Disconnects from the CDP endpoint and cancels all pending commands.
    func disconnect() async

    /// True when a WebSocket connection is currently open.
    var isConnected: Bool { get }

    /// Navigates the page to the given URL. Returns the frameId from Page.navigate.
    func navigate(url: String) async throws -> String

    /// Evaluates a JavaScript expression and returns the result as a string.
    func evaluateJS(_ expression: String) async throws -> String

    /// Returns true if a DOM element matching the CSS selector exists.
    func findElement(selector: String) async throws -> Bool

    /// Clicks the DOM element matching the CSS selector.
    func clickElement(selector: String) async throws

    /// Types text into the DOM element matching the CSS selector.
    func typeInElement(selector: String, text: String) async throws

    /// Returns `document.body.innerText` of the current page.
    func getText() async throws -> String

    /// Returns `window.location.href` of the current page.
    func getURL() async throws -> String
}
