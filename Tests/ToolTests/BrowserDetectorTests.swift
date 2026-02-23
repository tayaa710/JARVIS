import Testing
@testable import JARVIS

@Suite("BrowserDetector Tests")
struct BrowserDetectorTests {

    // MARK: - classifyBrowser

    @Test func testChromeDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.google.Chrome") == .chromium)
    }

    @Test func testEdgeDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.microsoft.edgemac") == .chromium)
    }

    @Test func testArcDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "company.thebrowser.Browser") == .chromium)
    }

    @Test func testBraveDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.brave.Browser") == .chromium)
    }

    @Test func testVivaldiDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.vivaldi.Vivaldi") == .chromium)
    }

    @Test func testOperaDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.operasoftware.Opera") == .chromium)
    }

    @Test func testSafariDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.apple.Safari") == .safari)
    }

    @Test func testSafariTechPreviewDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.apple.SafariTechnologyPreview") == .safari)
    }

    @Test func testFirefoxDetected() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "org.mozilla.firefox") == .firefox)
    }

    @Test func testUnknownBundleId() {
        let detector = BrowserDetector()
        #expect(detector.classifyBrowser(bundleId: "com.example.randomapp") == .unknown)
    }

    // MARK: - detectFrontmostBrowser

    @Test func testDetectFrontmostBrowserWhenNoBrowserRunning() {
        let detector = BrowserDetector(frontmostAppProvider: {
            (name: "Xcode", bundleId: "com.apple.dt.Xcode", pid: 1234)
        })
        #expect(detector.detectFrontmostBrowser() == nil)
    }

    @Test func testDetectFrontmostBrowserWhenBrowserRunning() {
        let detector = BrowserDetector(frontmostAppProvider: {
            (name: "Google Chrome", bundleId: "com.google.Chrome", pid: 5678)
        })
        let info = detector.detectFrontmostBrowser()
        #expect(info != nil)
        #expect(info?.name == "Google Chrome")
        #expect(info?.bundleId == "com.google.Chrome")
        #expect(info?.type == .chromium)
        #expect(info?.pid == 5678)
    }
}
