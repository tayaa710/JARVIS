@testable import JARVIS

// MARK: - MockBrowserDetector

/// Configurable mock implementation of BrowserDetecting.
/// Used by browser tool tests in M014/M015.
final class MockBrowserDetector: BrowserDetecting, @unchecked Sendable {

    // MARK: - Configurable Outputs

    var detectResult: BrowserInfo?
    var classifyResult: BrowserType = .unknown

    // MARK: - Call Recording

    var detectCallCount: Int = 0
    var classifyCallCount: Int = 0
    var lastClassifiedBundleId: String?

    // MARK: - BrowserDetecting

    func detectFrontmostBrowser() -> BrowserInfo? {
        detectCallCount += 1
        return detectResult
    }

    func classifyBrowser(bundleId: String) -> BrowserType {
        classifyCallCount += 1
        lastClassifiedBundleId = bundleId
        return classifyResult
    }
}
