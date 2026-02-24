import Foundation

// MARK: - BrowserError

/// Errors produced by BrowserRouter and browser backends.
public enum BrowserError: Error, Equatable {
    /// No browser is currently frontmost.
    case noBrowserDetected
    /// The frontmost browser is not supported (e.g. Firefox, unknown).
    case unsupportedBrowser(String)
    /// An AppleScript execution failed.
    case scriptFailed(String)
    /// URL navigation failed.
    case navigationFailed(String)
}
