import Testing
import Foundation
@testable import JARVIS

@Suite("BrowserRouter Tests")
struct BrowserRouterTests {

    // MARK: - Helpers

    private func safariInfo() -> BrowserInfo {
        BrowserInfo(name: "Safari", bundleId: "com.apple.Safari", type: .safari, pid: 1)
    }

    private func chromeInfo() -> BrowserInfo {
        BrowserInfo(name: "Google Chrome", bundleId: "com.google.Chrome", type: .chromium, pid: 2)
    }

    private func firefoxInfo() -> BrowserInfo {
        BrowserInfo(name: "Firefox", bundleId: "org.mozilla.firefox", type: .firefox, pid: 3)
    }

    private func makeRouter(
        browserInfo: BrowserInfo?,
        cdpBackend: MockCDPBackend = MockCDPBackend(),
        appleScriptRunner: @Sendable @escaping (String) async throws -> String = { _ in "" }
    ) -> BrowserRouter {
        let detector = MockBrowserDetector()
        detector.detectResult = browserInfo
        let appleScriptBackend = AppleScriptBackend(scriptRunner: appleScriptRunner)
        return BrowserRouter(
            detector: detector,
            cdpBackend: cdpBackend,
            appleScriptBackend: appleScriptBackend
        )
    }

    // MARK: - Routing

    @Test("Route to Safari uses AppleScript backend")
    func routeToSafariUsesAppleScriptBackend() async throws {
        var scriptCalled = false
        let router = makeRouter(browserInfo: safariInfo()) { script in
            scriptCalled = true
            return "https://example.com"
        }
        _ = try await router.getURL()
        #expect(scriptCalled)
    }

    @Test("Route to Chromium uses CDP backend")
    func routeToChromiumUsesCDPBackend() async throws {
        let cdp = MockCDPBackend()
        cdp._isConnected = true
        let router = makeRouter(browserInfo: chromeInfo(), cdpBackend: cdp)
        _ = try await router.getURL()
        #expect(cdp.getURLCallCount == 1)
    }

    @Test("Route to Firefox returns unsupportedBrowser error")
    func routeToFirefoxReturnsError() async throws {
        let router = makeRouter(browserInfo: firefoxInfo())
        do {
            try await router.navigate(url: "https://example.com")
            #expect(Bool(false), "Expected error")
        } catch let error as BrowserError {
            if case .unsupportedBrowser(let name) = error {
                #expect(name.contains("Firefox"))
            } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        }
    }

    @Test("Route to unknown browser returns unsupportedBrowser error")
    func routeToUnknownReturnsError() async throws {
        let unknownInfo = BrowserInfo(name: "Lynx", bundleId: "com.lynx", type: .unknown, pid: 4)
        let router = makeRouter(browserInfo: unknownInfo)
        do {
            try await router.navigate(url: "https://example.com")
            #expect(Bool(false), "Expected error")
        } catch let error as BrowserError {
            if case .unsupportedBrowser = error { /* pass */ } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        }
    }

    @Test("No browser detected returns noBrowserDetected error")
    func noBrowserDetectedReturnsError() async throws {
        let router = makeRouter(browserInfo: nil)
        do {
            try await router.navigate(url: "https://example.com")
            #expect(Bool(false), "Expected error")
        } catch let error as BrowserError {
            if case .noBrowserDetected = error { /* pass */ } else {
                #expect(Bool(false), "Wrong error: \(error)")
            }
        }
    }

    // MARK: - CDP Connection management

    @Test("CDP auto-connects on first call when not connected")
    func cdpAutoConnectsOnFirstCall() async throws {
        let cdp = MockCDPBackend()
        cdp._isConnected = false  // not yet connected
        let router = makeRouter(browserInfo: chromeInfo(), cdpBackend: cdp)
        _ = try await router.getURL()
        #expect(cdp.connectCallCount == 1)
        #expect(cdp.lastConnectPort == 9222)
    }

    @Test("CDP reuses existing connection across multiple calls")
    func cdpReusesExistingConnection() async throws {
        let cdp = MockCDPBackend()
        cdp._isConnected = true  // already connected
        let router = makeRouter(browserInfo: chromeInfo(), cdpBackend: cdp)
        _ = try await router.getURL()
        _ = try await router.getURL()
        _ = try await router.getURL()
        #expect(cdp.connectCallCount == 0)
        #expect(cdp.getURLCallCount == 3)
    }

    @Test("CDP reconnects if isConnected returns false")
    func cdpReconnectsAfterDisconnect() async throws {
        let cdp = MockCDPBackend()
        cdp._isConnected = false
        let router = makeRouter(browserInfo: chromeInfo(), cdpBackend: cdp)
        // First call: connects
        _ = try await router.getURL()
        #expect(cdp.connectCallCount == 1)
        // Simulate disconnect
        cdp._isConnected = false
        // Second call: reconnects
        _ = try await router.getURL()
        #expect(cdp.connectCallCount == 2)
    }

    // MARK: - End-to-end routing

    @Test("navigate routes correctly through Safari backend")
    func navigateRoutesThroughSafari() async throws {
        var capturedURL: String?
        let router = makeRouter(browserInfo: safariInfo()) { script in
            if script.contains("set URL") {
                capturedURL = "https://apple.com"
            }
            return ""
        }
        try await router.navigate(url: "https://apple.com")
        #expect(capturedURL == "https://apple.com")
    }

    @Test("getURL routes correctly through CDP backend")
    func getURLRoutesThroughCDP() async throws {
        let cdp = MockCDPBackend()
        cdp._isConnected = true
        cdp.getURLResult = "https://google.com"
        let router = makeRouter(browserInfo: chromeInfo(), cdpBackend: cdp)
        let url = try await router.getURL()
        #expect(url == "https://google.com")
        #expect(cdp.getURLCallCount == 1)
    }
}
