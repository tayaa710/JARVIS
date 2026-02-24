import Testing
import Foundation
@testable import JARVIS

@Suite("BrowserError Localization Tests")
struct BrowserErrorLocalizationTests {

    @Test("noBrowserDetected has descriptive message")
    func noBrowserDetected() {
        let error = BrowserError.noBrowserDetected
        let message = error.localizedDescription
        #expect(message.contains("No browser"))
        #expect(message.contains("foreground"))
    }

    @Test("unsupportedBrowser includes detail")
    func unsupportedBrowser() {
        let error = BrowserError.unsupportedBrowser("Firefox is not supported")
        let message = error.localizedDescription
        #expect(message.contains("Firefox is not supported"))
    }

    @Test("scriptFailed includes detail and automation hint")
    func scriptFailed() {
        let error = BrowserError.scriptFailed("NSAppleScriptErrorNumber = -1743")
        let message = error.localizedDescription
        #expect(message.contains("-1743"))
        #expect(message.contains("automation") || message.contains("Apple Events"))
    }

    @Test("all BrowserError cases have non-empty localized descriptions")
    func allCasesHaveDescriptions() {
        let cases: [BrowserError] = [
            .noBrowserDetected,
            .unsupportedBrowser("test"),
            .scriptFailed("test"),
            .navigationFailed("test")
        ]
        for error in cases {
            #expect(!error.localizedDescription.isEmpty,
                    "BrowserError should have a description")
            // Should NOT contain the default "The operation couldn't be completed"
            #expect(!error.localizedDescription.contains("BrowserError error"),
                    "BrowserError should not use default error description")
        }
    }
}
