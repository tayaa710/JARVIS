import Foundation
import AppKit

// MARK: - AppleScriptBackend

/// Controls browsers via AppleScript + JavaScript injection.
/// Uses a `dialect` to generate correct AppleScript for Safari vs Chromium.
/// Uses closure injection for the script runner so tests can verify
/// generated scripts without executing real AppleScript.
public final class AppleScriptBackend: BrowserBackend, @unchecked Sendable {

    // MARK: - Properties

    /// The AppleScript dialect (Safari vs Chrome) that determines command syntax.
    public let dialect: AppleScriptDialect

    /// Closure that executes an AppleScript string and returns the result.
    /// Production default uses NSAppleScript on the main actor.
    /// Internal access so BrowserRouter can reuse it for fallback backends.
    let scriptRunner: @Sendable (String) async throws -> String

    // MARK: - Init

    public init(
        dialect: AppleScriptDialect = .safari,
        scriptRunner: @Sendable @escaping (String) async throws -> String = { script in
            return try await MainActor.run {
                let appleScript = NSAppleScript(source: script)
                var errorInfo: NSDictionary?
                let descriptor = appleScript?.executeAndReturnError(&errorInfo)
                if let error = errorInfo {
                    let message = error["NSAppleScriptErrorMessage"] as? String
                        ?? error.description
                    throw BrowserError.scriptFailed(message)
                }
                return descriptor?.stringValue ?? ""
            }
        }
    ) {
        self.dialect = dialect
        self.scriptRunner = scriptRunner
    }

    // MARK: - BrowserBackend

    public func navigate(url: String) async throws {
        let escapedURL = escapeAppleScriptString(url)
        let script = dialect.navigateScript(escapedURL: escapedURL)
        Logger.browser.info("AppleScript navigate (\(dialect.appName)): \(url)")
        _ = try await scriptRunner(script)
    }

    public func getURL() async throws -> String {
        let script = dialect.getURLScript()
        Logger.browser.info("AppleScript getURL (\(dialect.appName))")
        return try await scriptRunner(script)
    }

    public func getText() async throws -> String {
        let js = escapeAppleScriptString("document.body.innerText.substring(0, 10000)")
        let script = dialect.executeJSScript(js: js)
        Logger.browser.info("AppleScript getText (\(dialect.appName))")
        return try await scriptRunner(script)
    }

    public func findElement(selector: String) async throws -> Bool {
        let escapedSelector = escapeJSString(selector)
        let js = escapeAppleScriptString("!!document.querySelector('\(escapedSelector)')")
        let script = dialect.executeJSScript(js: js)
        Logger.browser.info("AppleScript findElement (\(dialect.appName)): \(selector)")
        let result = try await scriptRunner(script)
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    public func clickElement(selector: String) async throws {
        let escapedSelector = escapeJSString(selector)
        let jsCode = "(function(){ var el = document.querySelector('\(escapedSelector)'); if (!el) throw new Error('Not found'); el.click(); })()"
        let js = escapeAppleScriptString(jsCode)
        let script = dialect.executeJSScript(js: js)
        Logger.browser.info("AppleScript clickElement (\(dialect.appName)): \(selector)")
        _ = try await scriptRunner(script)
    }

    public func typeInElement(selector: String, text: String) async throws {
        let escapedSelector = escapeJSString(selector)
        let escapedText = escapeJSString(text)
        let jsCode = "(function(){ var el = document.querySelector('\(escapedSelector)'); if (!el) throw new Error('Not found'); el.focus(); el.value = '\(escapedText)'; el.dispatchEvent(new Event('input', {bubbles:true})); el.dispatchEvent(new Event('change', {bubbles:true})); })()"
        let js = escapeAppleScriptString(jsCode)
        let script = dialect.executeJSScript(js: js)
        Logger.browser.info("AppleScript typeInElement (\(dialect.appName)): \(selector)")
        _ = try await scriptRunner(script)
    }

    public func evaluateJS(_ expression: String) async throws -> String {
        let js = escapeAppleScriptString(expression)
        let script = dialect.executeJSScript(js: js)
        Logger.browser.info("AppleScript evaluateJS (\(dialect.appName))")
        return try await scriptRunner(script)
    }

    // MARK: - Private: String Escaping

    /// Escapes a string for use inside an AppleScript double-quoted string literal.
    /// AppleScript requires backslash and double-quote to be escaped.
    private func escapeAppleScriptString(_ string: String) -> String {
        var result = ""
        for char in string {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            default:   result.append(char)
            }
        }
        return result
    }

    /// Escapes a string for use inside a JavaScript single-quoted string
    /// that itself lives inside an AppleScript double-quoted string.
    /// Handles both JS escaping and AppleScript string escaping.
    private func escapeJSString(_ string: String) -> String {
        var result = ""
        for char in string {
            switch char {
            case "\\": result += "\\\\\\\\"  // \\ in JS, \\ in AppleScript → \\\\
            case "\"": result += "\\\""       // escape for AppleScript
            case "'":  result += "\\'"        // escape for JS
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            default:   result.append(char)
            }
        }
        return result
    }
}
