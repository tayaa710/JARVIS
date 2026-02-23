import AppKit

// MARK: - BrowserDetector

/// Production implementation of BrowserDetecting.
/// Stateless — detects the frontmost browser by matching its bundle ID
/// against a known set of browser bundle identifiers.
struct BrowserDetector: BrowserDetecting {

    // MARK: - Known Bundle IDs

    private static let knownBrowsers: [String: BrowserType] = [
        // Chromium-based
        "com.google.Chrome":              .chromium,
        "com.google.Chrome.canary":       .chromium,
        "com.microsoft.edgemac":          .chromium,
        "company.thebrowser.Browser":     .chromium,  // Arc
        "com.brave.Browser":              .chromium,
        "com.vivaldi.Vivaldi":            .chromium,
        "com.operasoftware.Opera":        .chromium,
        // Safari
        "com.apple.Safari":               .safari,
        "com.apple.SafariTechnologyPreview": .safari,
        // Firefox
        "org.mozilla.firefox":            .firefox,
        "org.mozilla.firefoxdeveloperedition": .firefox,
    ]

    // MARK: - Frontmost App Provider

    /// Closure that returns (name, bundleId, pid) for the frontmost app, or nil.
    /// Defaults to NSWorkspace.shared.frontmostApplication for production.
    /// Injected in tests to keep them deterministic.
    let frontmostAppProvider: @Sendable () -> (name: String, bundleId: String, pid: pid_t)?

    init(
        frontmostAppProvider: @Sendable @escaping () -> (name: String, bundleId: String, pid: pid_t)? = {
            guard let app = NSWorkspace.shared.frontmostApplication,
                  let name = app.localizedName,
                  let bundleId = app.bundleIdentifier else { return nil }
            return (name: name, bundleId: bundleId, pid: app.processIdentifier)
        }
    ) {
        self.frontmostAppProvider = frontmostAppProvider
    }

    // MARK: - BrowserDetecting

    func classifyBrowser(bundleId: String) -> BrowserType {
        return Self.knownBrowsers[bundleId] ?? .unknown
    }

    func detectFrontmostBrowser() -> BrowserInfo? {
        guard let app = frontmostAppProvider() else { return nil }
        let type = classifyBrowser(bundleId: app.bundleId)
        guard type != .unknown else { return nil }
        return BrowserInfo(name: app.name, bundleId: app.bundleId, type: type, pid: app.pid)
    }
}
