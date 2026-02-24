import Testing
import Foundation
@testable import JARVIS

@Suite("AppleScriptDialect Tests")
struct AppleScriptDialectTests {

    // MARK: - App Name

    @Test("safari dialect returns Safari as app name")
    func safariAppName() {
        let dialect = AppleScriptDialect.safari
        #expect(dialect.appName == "Safari")
    }

    @Test("chrome dialect returns custom app name")
    func chromeAppName() {
        let dialect = AppleScriptDialect.chrome(appName: "Google Chrome")
        #expect(dialect.appName == "Google Chrome")
    }

    @Test("chrome dialect with Arc returns Arc")
    func arcAppName() {
        let dialect = AppleScriptDialect.chrome(appName: "Arc")
        #expect(dialect.appName == "Arc")
    }

    // MARK: - Navigate Script

    @Test("safari navigate script uses 'set URL of current tab'")
    func safariNavigateScript() {
        let script = AppleScriptDialect.safari.navigateScript(escapedURL: "https://example.com")
        #expect(script.contains("tell application \"Safari\""))
        #expect(script.contains("set URL of current tab of front window"))
        #expect(script.contains("https://example.com"))
    }

    @Test("chrome navigate script uses 'set URL of active tab'")
    func chromeNavigateScript() {
        let script = AppleScriptDialect.chrome(appName: "Google Chrome")
            .navigateScript(escapedURL: "https://example.com")
        #expect(script.contains("tell application \"Google Chrome\""))
        #expect(script.contains("set URL of active tab of front window"))
        #expect(script.contains("https://example.com"))
    }

    // MARK: - Get URL Script

    @Test("safari getURL script uses 'get URL of current tab'")
    func safariGetURLScript() {
        let script = AppleScriptDialect.safari.getURLScript()
        #expect(script.contains("tell application \"Safari\""))
        #expect(script.contains("get URL of current tab of front window"))
    }

    @Test("chrome getURL script uses 'get URL of active tab'")
    func chromeGetURLScript() {
        let script = AppleScriptDialect.chrome(appName: "Google Chrome").getURLScript()
        #expect(script.contains("tell application \"Google Chrome\""))
        #expect(script.contains("get URL of active tab of front window"))
    }

    // MARK: - Execute JS Script

    @Test("safari executeJS script uses 'do JavaScript ... in current tab'")
    func safariExecuteJSScript() {
        let script = AppleScriptDialect.safari.executeJSScript(js: "document.title")
        #expect(script.contains("tell application \"Safari\""))
        #expect(script.contains("do JavaScript"))
        #expect(script.contains("in current tab of front window"))
        #expect(script.contains("document.title"))
    }

    @Test("chrome executeJS script uses 'execute front window's active tab javascript'")
    func chromeExecuteJSScript() {
        let script = AppleScriptDialect.chrome(appName: "Google Chrome")
            .executeJSScript(js: "document.title")
        #expect(script.contains("tell application \"Google Chrome\""))
        #expect(script.contains("execute front window's active tab javascript"))
        #expect(script.contains("document.title"))
    }

    // MARK: - Equatable

    @Test("dialects are equatable")
    func equatable() {
        #expect(AppleScriptDialect.safari == AppleScriptDialect.safari)
        #expect(AppleScriptDialect.chrome(appName: "Chrome") == AppleScriptDialect.chrome(appName: "Chrome"))
        #expect(AppleScriptDialect.safari != AppleScriptDialect.chrome(appName: "Chrome"))
        #expect(AppleScriptDialect.chrome(appName: "Chrome") != AppleScriptDialect.chrome(appName: "Arc"))
    }
}
