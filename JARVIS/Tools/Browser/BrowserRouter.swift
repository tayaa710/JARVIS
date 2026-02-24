import Foundation

// MARK: - BrowserRouter

/// Routes browser commands to the correct backend based on the frontmost browser.
/// - Safari → AppleScriptBackend
/// - Chromium (Chrome, Arc, Edge, Brave, etc.) → CDPBackendProtocol
/// - Firefox / unknown → BrowserError.unsupportedBrowser
/// - Nothing frontmost → BrowserError.noBrowserDetected
///
/// CDP auto-connects on first use and reconnects if the connection drops.
public final class BrowserRouter: BrowserBackend, @unchecked Sendable {

    // MARK: - Dependencies

    private let detector: any BrowserDetecting
    private let cdpBackend: any CDPBackendProtocol
    private let appleScriptBackend: AppleScriptBackend
    private let cdpPort: Int

    // MARK: - Init

    public init(
        detector: any BrowserDetecting,
        cdpBackend: any CDPBackendProtocol,
        appleScriptBackend: AppleScriptBackend,
        cdpPort: Int = 9222
    ) {
        self.detector = detector
        self.cdpBackend = cdpBackend
        self.appleScriptBackend = appleScriptBackend
        self.cdpPort = cdpPort
    }

    // MARK: - BrowserBackend

    public func navigate(url: String) async throws {
        let backend = try await resolveBackend()
        Logger.browser.info("BrowserRouter navigate: \(url)")
        try await backend.navigate(url: url)
    }

    public func getURL() async throws -> String {
        let backend = try await resolveBackend()
        return try await backend.getURL()
    }

    public func getText() async throws -> String {
        let backend = try await resolveBackend()
        return try await backend.getText()
    }

    public func findElement(selector: String) async throws -> Bool {
        let backend = try await resolveBackend()
        return try await backend.findElement(selector: selector)
    }

    public func clickElement(selector: String) async throws {
        let backend = try await resolveBackend()
        try await backend.clickElement(selector: selector)
    }

    public func typeInElement(selector: String, text: String) async throws {
        let backend = try await resolveBackend()
        try await backend.typeInElement(selector: selector, text: text)
    }

    public func evaluateJS(_ expression: String) async throws -> String {
        let backend = try await resolveBackend()
        return try await backend.evaluateJS(expression)
    }

    // MARK: - Private

    /// Detects the frontmost browser and returns the appropriate backend.
    /// For Chromium, ensures CDP is connected before returning.
    private func resolveBackend() async throws -> any BrowserBackend {
        guard let info = detector.detectFrontmostBrowser() else {
            throw BrowserError.noBrowserDetected
        }

        switch info.type {
        case .safari:
            return appleScriptBackend

        case .chromium:
            if !cdpBackend.isConnected {
                do {
                    try await cdpBackend.connect(port: cdpPort)
                } catch {
                    Logger.browser.error("CDP connect failed: \(error)")
                    throw error
                }
            }
            return CDPBrowserBackendAdapter(backend: cdpBackend)

        case .firefox:
            throw BrowserError.unsupportedBrowser("\(info.name) is not supported. Use Safari or a Chromium browser.")

        case .unknown:
            throw BrowserError.unsupportedBrowser("\(info.name) is not a supported browser.")
        }
    }
}

// MARK: - CDPBrowserBackendAdapter

/// Adapts CDPBackendProtocol (which has navigate returning String) to BrowserBackend (navigate returns Void).
private struct CDPBrowserBackendAdapter: BrowserBackend {
    let backend: any CDPBackendProtocol

    func navigate(url: String) async throws {
        _ = try await backend.navigate(url: url)
    }

    func getURL() async throws -> String {
        return try await backend.getURL()
    }

    func getText() async throws -> String {
        return try await backend.getText()
    }

    func findElement(selector: String) async throws -> Bool {
        return try await backend.findElement(selector: selector)
    }

    func clickElement(selector: String) async throws {
        try await backend.clickElement(selector: selector)
    }

    func typeInElement(selector: String, text: String) async throws {
        try await backend.typeInElement(selector: selector, text: text)
    }

    func evaluateJS(_ expression: String) async throws -> String {
        return try await backend.evaluateJS(expression)
    }
}
