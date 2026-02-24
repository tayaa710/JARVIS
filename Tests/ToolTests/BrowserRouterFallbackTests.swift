import Testing
import Foundation
@testable import JARVIS

/// Captures app names passed to the fallback factory.
private final class FallbackCapture: @unchecked Sendable {
    var appNames: [String] = []
}

@Suite("BrowserRouter Fallback Tests")
struct BrowserRouterFallbackTests {

    // MARK: - Helpers

    private func makeChromeInfo(name: String = "Google Chrome") -> BrowserInfo {
        BrowserInfo(name: name, bundleId: "com.google.Chrome", type: .chromium, pid: 1234)
    }

    private func makeRouter(
        browserInfo: BrowserInfo?,
        cdpBackend: MockCDPBackend,
        capture: FallbackCapture
    ) -> BrowserRouter {
        let detector = MockBrowserDetector()
        detector.detectResult = browserInfo
        let safari = AppleScriptBackend { _ in "" }

        let router = BrowserRouter(
            detector: detector,
            cdpBackend: cdpBackend,
            appleScriptBackend: safari,
            appleScriptFallbackFactory: { appName in
                capture.appNames.append(appName)
                return AppleScriptBackend(dialect: .chrome(appName: appName)) { _ in "" }
            }
        )
        return router
    }

    // MARK: - CDP Success → Uses CDP

    @Test("chromium browser with successful CDP connect uses CDP backend")
    func cdpSuccessUsesCDP() async throws {
        let detector = MockBrowserDetector()
        detector.detectResult = makeChromeInfo()
        let cdp = MockCDPBackend()
        cdp.getURLResult = "https://cdp-url.com"
        let safari = AppleScriptBackend { _ in "" }

        let router = BrowserRouter(
            detector: detector,
            cdpBackend: cdp,
            appleScriptBackend: safari
        )

        let url = try await router.getURL()
        #expect(url == "https://cdp-url.com")
        #expect(cdp.connectCallCount == 1)
        #expect(cdp.getURLCallCount == 1)
    }

    // MARK: - CDP Failure → Falls Back to AppleScript

    @Test("chromium browser with CDP failure falls back to AppleScript")
    func cdpFailureFallsBackToAppleScript() async throws {
        let cdp = MockCDPBackend()
        cdp.connectShouldThrow = .connectionFailed("refused")
        let capture = FallbackCapture()

        let router = makeRouter(
            browserInfo: makeChromeInfo(),
            cdpBackend: cdp,
            capture: capture
        )

        // Should not throw — falls back to AppleScript
        try await router.navigate(url: "https://example.com")
        #expect(cdp.connectCallCount == 1)
        #expect(capture.appNames == ["Google Chrome"])
    }

    @Test("fallback uses correct app name from browser info")
    func fallbackUsesCorrectAppName() async throws {
        let cdp = MockCDPBackend()
        cdp.connectShouldThrow = .discoveryFailed("no port")
        let capture = FallbackCapture()

        let router = makeRouter(
            browserInfo: makeChromeInfo(name: "Brave Browser"),
            cdpBackend: cdp,
            capture: capture
        )

        try await router.navigate(url: "https://example.com")
        #expect(capture.appNames == ["Brave Browser"])
    }

    @Test("already-connected CDP does not reconnect")
    func alreadyConnectedSkipsConnect() async throws {
        let detector = MockBrowserDetector()
        detector.detectResult = makeChromeInfo()
        let cdp = MockCDPBackend()
        cdp._isConnected = true
        cdp.getURLResult = "https://connected.com"
        let safari = AppleScriptBackend { _ in "" }

        let router = BrowserRouter(
            detector: detector,
            cdpBackend: cdp,
            appleScriptBackend: safari
        )

        let url = try await router.getURL()
        #expect(url == "https://connected.com")
        #expect(cdp.connectCallCount == 0)
    }

    // MARK: - Safari still uses Safari backend

    @Test("safari browser uses AppleScript backend not CDP")
    func safariUsesSafariBackend() async throws {
        let detector = MockBrowserDetector()
        detector.detectResult = BrowserInfo(name: "Safari", bundleId: "com.apple.Safari", type: .safari, pid: 5678)
        let cdp = MockCDPBackend()
        let scriptCapture = FallbackCapture()
        let safari = AppleScriptBackend(dialect: .safari) { script in
            scriptCapture.appNames.append(script)
            return "https://safari-url.com"
        }

        let router = BrowserRouter(
            detector: detector,
            cdpBackend: cdp,
            appleScriptBackend: safari
        )

        let url = try await router.getURL()
        #expect(url == "https://safari-url.com")
        #expect(cdp.connectCallCount == 0)
        #expect(scriptCapture.appNames.count == 1)
    }
}
