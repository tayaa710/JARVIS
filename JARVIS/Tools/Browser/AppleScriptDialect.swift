import Foundation

// MARK: - AppleScriptDialect

/// Encapsulates AppleScript syntax differences between Safari and Chromium browsers.
/// Safari and Chrome use different AppleScript commands for tab/window manipulation.
public enum AppleScriptDialect: Sendable, Equatable {
    /// Safari: `set URL of current tab of front window`, `do JavaScript ... in current tab of front window`
    case safari
    /// Chromium browsers (Chrome, Arc, Edge, Brave): uses `active tab` and `execute` syntax.
    /// The associated `appName` is the application name for the `tell` block (e.g. "Google Chrome").
    case chrome(appName: String)

    // MARK: - Application Name

    /// The application name used in `tell application "..."` blocks.
    public var appName: String {
        switch self {
        case .safari:
            return "Safari"
        case .chrome(let name):
            return name
        }
    }

    // MARK: - Script Generation

    /// Generates a script that navigates the current tab to the given URL.
    /// The `escapedURL` parameter must already be escaped for AppleScript string embedding.
    public func navigateScript(escapedURL: String) -> String {
        switch self {
        case .safari:
            return """
            tell application "Safari"
                set URL of current tab of front window to "\(escapedURL)"
            end tell
            """
        case .chrome(let name):
            return """
            tell application "\(name)"
                set URL of active tab of front window to "\(escapedURL)"
            end tell
            """
        }
    }

    /// Generates a script that returns the URL of the current tab.
    public func getURLScript() -> String {
        switch self {
        case .safari:
            return """
            tell application "Safari"
                get URL of current tab of front window
            end tell
            """
        case .chrome(let name):
            return """
            tell application "\(name)"
                get URL of active tab of front window
            end tell
            """
        }
    }

    /// Generates a script that executes JavaScript in the current tab.
    /// The `js` parameter must already be escaped for AppleScript string embedding.
    public func executeJSScript(js: String) -> String {
        switch self {
        case .safari:
            return """
            tell application "Safari"
                do JavaScript "\(js)" in current tab of front window
            end tell
            """
        case .chrome(let name):
            return """
            tell application "\(name)"
                execute front window's active tab javascript "\(js)"
            end tell
            """
        }
    }
}
