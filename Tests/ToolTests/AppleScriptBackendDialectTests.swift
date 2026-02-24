import Testing
import Foundation
@testable import JARVIS

@Suite("AppleScriptBackend Dialect Tests")
struct AppleScriptBackendDialectTests {

    // MARK: - Helpers

    /// Creates a backend with a recording script runner.
    /// Returns the backend and a closure to retrieve captured scripts.
    private func makeBackend(
        dialect: AppleScriptDialect,
        result: String = ""
    ) -> (AppleScriptBackend, () -> [String]) {
        var capturedScripts: [String] = []
        let backend = AppleScriptBackend(dialect: dialect) { script in
            capturedScripts.append(script)
            return result
        }
        return (backend, { capturedScripts })
    }

    // MARK: - Safari dialect (default)

    @Test("default dialect is safari")
    func defaultDialect() {
        let backend = AppleScriptBackend { _ in "" }
        #expect(backend.dialect == .safari)
    }

    @Test("safari dialect navigate generates Safari AppleScript")
    func safariNavigate() async throws {
        let (backend, scripts) = makeBackend(dialect: .safari)
        try await backend.navigate(url: "https://swift.org")
        let captured = scripts()
        #expect(captured.count == 1)
        #expect(captured[0].contains("tell application \"Safari\""))
        #expect(captured[0].contains("set URL of current tab"))
    }

    @Test("safari dialect evaluateJS generates Safari do JavaScript")
    func safariEvaluateJS() async throws {
        let (backend, scripts) = makeBackend(dialect: .safari, result: "test")
        _ = try await backend.evaluateJS("document.title")
        let captured = scripts()
        #expect(captured.count == 1)
        #expect(captured[0].contains("do JavaScript"))
        #expect(captured[0].contains("in current tab of front window"))
    }

    // MARK: - Chrome dialect

    @Test("chrome dialect navigate generates Chrome AppleScript")
    func chromeNavigate() async throws {
        let (backend, scripts) = makeBackend(dialect: .chrome(appName: "Google Chrome"))
        try await backend.navigate(url: "https://swift.org")
        let captured = scripts()
        #expect(captured.count == 1)
        #expect(captured[0].contains("tell application \"Google Chrome\""))
        #expect(captured[0].contains("set URL of active tab"))
    }

    @Test("chrome dialect evaluateJS generates Chrome execute javascript")
    func chromeEvaluateJS() async throws {
        let (backend, scripts) = makeBackend(dialect: .chrome(appName: "Google Chrome"), result: "test")
        _ = try await backend.evaluateJS("document.title")
        let captured = scripts()
        #expect(captured.count == 1)
        #expect(captured[0].contains("execute front window's active tab javascript"))
    }

    @Test("chrome dialect getURL generates Chrome AppleScript")
    func chromeGetURL() async throws {
        let (backend, scripts) = makeBackend(dialect: .chrome(appName: "Google Chrome"), result: "https://example.com")
        _ = try await backend.getURL()
        let captured = scripts()
        #expect(captured.count == 1)
        #expect(captured[0].contains("tell application \"Google Chrome\""))
        #expect(captured[0].contains("get URL of active tab"))
    }

    @Test("custom app name is used in chrome dialect")
    func customAppName() async throws {
        let (backend, scripts) = makeBackend(dialect: .chrome(appName: "Brave Browser"))
        try await backend.navigate(url: "https://example.com")
        let captured = scripts()
        #expect(captured[0].contains("tell application \"Brave Browser\""))
    }
}
