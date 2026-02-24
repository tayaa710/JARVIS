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

// MARK: - BrowserError + LocalizedError

extension BrowserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noBrowserDetected:
            return "No browser is currently in the foreground. Bring a browser window to the front and try again."
        case .unsupportedBrowser(let detail):
            return "Unsupported browser: \(detail)"
        case .scriptFailed(let detail):
            return "Browser script execution failed: \(detail). Check that the browser allows automation (Safari > Develop > Allow JavaScript from Apple Events; Chrome allows AppleScript by default)."
        case .navigationFailed(let detail):
            return "Browser navigation failed: \(detail)."
        }
    }
}
