import Testing
import Foundation
@testable import JARVIS

@Suite("CDPError Localization Tests")
struct CDPErrorLocalizationTests {

    @Test("connectionFailed has descriptive message mentioning remote debugging port")
    func connectionFailed() {
        let error = CDPError.connectionFailed("Connection refused")
        let message = error.localizedDescription
        #expect(message.contains("Connection refused"))
        #expect(message.contains("--remote-debugging-port"))
    }

    @Test("commandTimeout has descriptive message")
    func commandTimeout() {
        let error = CDPError.commandTimeout("Runtime.evaluate")
        let message = error.localizedDescription
        #expect(message.contains("Runtime.evaluate"))
        #expect(message.contains("timed out"))
    }

    @Test("notConnected has descriptive message")
    func notConnected() {
        let error = CDPError.notConnected
        let message = error.localizedDescription
        #expect(message.contains("Not connected"))
        #expect(message.contains("remote debugging"))
    }

    @Test("noTargetsFound suggests opening a tab")
    func noTargetsFound() {
        let error = CDPError.noTargetsFound
        let message = error.localizedDescription
        #expect(message.contains("No browser tabs"))
        #expect(message.contains("Open a tab"))
    }

    @Test("all CDPError cases have non-empty localized descriptions")
    func allCasesHaveDescriptions() {
        let cases: [CDPError] = [
            .connectionFailed("test"),
            .commandTimeout("test"),
            .invalidResponse("test"),
            .evaluationError("test"),
            .notConnected,
            .discoveryFailed("test"),
            .noTargetsFound,
            .connectionClosed
        ]
        for error in cases {
            #expect(!error.localizedDescription.isEmpty, "CDPError.\(error) should have a description")
            // Should NOT contain "CDPError error N" pattern (the default)
            #expect(!error.localizedDescription.contains("CDPError error"),
                    "CDPError.\(error) should not use default error description")
        }
    }
}
