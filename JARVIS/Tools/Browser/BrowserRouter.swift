import Foundation

// MARK: - BrowserRouter

/// Routes browser commands to the correct backend based on the frontmost browser.
/// - Safari → AppleScriptBackend (safari dialect)
/// - Chromium (Chrome, Arc, Edge, Brave, etc.) → CDPBackendProtocol, with AppleScript fallback
/// - Firefox / unknown → BrowserError.unsupportedBrowser
/// - Nothing frontmost → BrowserError.noBrowserDetected
///
/// CDP auto-connects on first use. If CDP connection fails (e.g. Chrome wasn't launched
/// with --remote-debugging-port), falls back to AppleScript with the chrome dialect.
public final class BrowserRouter: BrowserBackend, @unchecked Sendable {

    // MARK: - Dependencies

    private let detector: any BrowserDetecting
    private let cdpBackend: any CDPBackendProtocol
    private let appleScriptBackend: AppleScriptBackend
    private let cdpPort: Int

    /// Factory for creating AppleScript fallback backends for Chromium browsers.
    /// Internal for testing — production uses the default that creates a real backend.
    let appleScriptFallbackFactory: @Sendable (String) -> AppleScriptBackend

    // MARK: - Init

    public init(
        detector: any BrowserDetecting,
        cdpBackend: any CDPBackendProtocol,
        appleScriptBackend: AppleScriptBackend,
        cdpPort: Int = 9222,
        appleScriptFallbackFactory: (@Sendable (String) -> AppleScriptBackend)? = nil
    ) {
        self.detector = detector
        self.cdpBackend = cdpBackend
        self.appleScriptBackend = appleScriptBackend
        self.cdpPort = cdpPort
        self.appleScriptFallbackFactory = appleScriptFallbackFactory ?? { appName in
            AppleScriptBackend(dialect: .chrome(appName: appName))
        }
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
    /// For Chromium, tries CDP first; falls back to AppleScript if CDP connect fails.
    private func resolveBackend() async throws -> any BrowserBackend {
        guard let info = detector.detectFrontmostBrowser() else {
            throw BrowserError.noBrowserDetected
        }

        switch info.type {
        case .safari:
            return appleScriptBackend

        case .chromium:
            if cdpBackend.isConnected {
                return CDPBrowserBackendAdapter(backend: cdpBackend)
            }
            do {
                try await cdpBackend.connect(port: cdpPort)
                return CDPBrowserBackendAdapter(backend: cdpBackend)
            } catch {
                Logger.browser.warning(
                    "CDP connect failed for \(info.name), falling back to AppleScript: \(error.localizedDescription)"
                )
                return appleScriptFallbackFactory(info.name)
            }

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
