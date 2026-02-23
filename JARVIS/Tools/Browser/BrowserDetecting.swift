import Foundation

// MARK: - BrowserDetecting

/// Detects and classifies browser applications.
public protocol BrowserDetecting: Sendable {
    /// Returns info about the frontmost app if it is a known browser, otherwise nil.
    func detectFrontmostBrowser() -> BrowserInfo?

    /// Maps a bundle ID to a BrowserType. Returns .unknown for unrecognised bundle IDs.
    func classifyBrowser(bundleId: String) -> BrowserType
}
