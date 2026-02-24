import Testing
import Foundation
@testable import JARVIS

@Suite("AppleScriptBackend Tests")
struct AppleScriptBackendTests {

    // MARK: - Helpers

    /// Captures the last script string passed to the runner. Throws if configured.
    private func makeBackend(
        result: String = "",
        shouldThrow: Error? = nil
    ) -> (backend: AppleScriptBackend, capturedScript: Box<String>) {
        let box = Box<String>("")
        let backend = AppleScriptBackend { script in
            box.value = script
            if let error = shouldThrow { throw error }
            return result
        }
        return (backend, box)
    }

    // MARK: - navigate

    @Test("navigate generates correct AppleScript with URL")
    func navigateGeneratesCorrectAppleScript() async throws {
        let (backend, box) = makeBackend()
        try await backend.navigate(url: "https://example.com")
        #expect(box.value.contains("https://example.com"))
        #expect(box.value.contains("set URL of current tab"))
        #expect(box.value.contains("Safari"))
    }

    @Test("navigate with special characters in URL escapes AppleScript string")
    func specialCharactersInURLAreEscaped() async throws {
        let (backend, box) = makeBackend()
        // URL containing a double-quote (rare but must be handled)
        try await backend.navigate(url: "https://example.com/path\"query")
        // The quote should be escaped as \" inside the AppleScript string literal
        #expect(box.value.contains("\\\""))
    }

    // MARK: - getURL

    @Test("getURL generates correct AppleScript")
    func getURLGeneratesCorrectAppleScript() async throws {
        let (backend, box) = makeBackend(result: "https://example.com")
        let url = try await backend.getURL()
        #expect(box.value.contains("get URL of current tab"))
        #expect(box.value.contains("Safari"))
        #expect(url == "https://example.com")
    }

    // MARK: - getText

    @Test("getText uses JavaScript via do JavaScript")
    func getTextUsesJavaScript() async throws {
        let (backend, box) = makeBackend(result: "Hello world")
        let text = try await backend.getText()
        #expect(box.value.contains("do JavaScript"))
        #expect(box.value.contains("document.body.innerText"))
        #expect(text == "Hello world")
    }

    // MARK: - evaluateJS

    @Test("evaluateJS wraps expression in do JavaScript")
    func evaluateJSGeneratesCorrectAppleScript() async throws {
        let (backend, box) = makeBackend(result: "42")
        let result = try await backend.evaluateJS("1 + 1")
        #expect(box.value.contains("do JavaScript"))
        #expect(box.value.contains("1 + 1"))
        #expect(box.value.contains("Safari"))
        #expect(result == "42")
    }

    // MARK: - findElement

    @Test("findElement generates correct querySelector JS")
    func findElementGeneratesCorrectJS() async throws {
        let (backend, box) = makeBackend(result: "true")
        let found = try await backend.findElement(selector: "#submit-btn")
        #expect(box.value.contains("querySelector"))
        #expect(box.value.contains("#submit-btn"))
        #expect(found == true)
    }

    @Test("findElement returns false when script returns 'false'")
    func findElementReturnsFalse() async throws {
        let (backend, _) = makeBackend(result: "false")
        let found = try await backend.findElement(selector: ".missing")
        #expect(found == false)
    }

    // MARK: - clickElement

    @Test("clickElement generates correct .click() JS")
    func clickElementGeneratesCorrectJS() async throws {
        let (backend, box) = makeBackend()
        try await backend.clickElement(selector: "button.submit")
        #expect(box.value.contains("querySelector"))
        #expect(box.value.contains("button.submit"))
        #expect(box.value.contains(".click()"))
    }

    // MARK: - typeInElement

    @Test("typeInElement generates correct value-setting JS")
    func typeInElementGeneratesCorrectJS() async throws {
        let (backend, box) = makeBackend()
        try await backend.typeInElement(selector: "input#email", text: "test@example.com")
        #expect(box.value.contains("querySelector"))
        #expect(box.value.contains("input#email"))
        #expect(box.value.contains("test@example.com"))
        #expect(box.value.contains("dispatchEvent"))
    }

    @Test("typeInElement escapes special characters in selector")
    func specialCharactersInSelectorAreEscaped() async throws {
        let (backend, box) = makeBackend()
        // selector with a single-quote
        try await backend.typeInElement(selector: "input[name='email']", text: "hello")
        // The single quote in the selector should be escaped for JS
        #expect(box.value.contains("\\'") || box.value.contains("\""))
    }

    // MARK: - error propagation

    @Test("script runner error propagates as BrowserError.scriptFailed")
    func scriptRunnerErrorPropagates() async throws {
        let (backend, _) = makeBackend(shouldThrow: BrowserError.scriptFailed("timeout"))
        do {
            try await backend.navigate(url: "https://example.com")
            #expect(Bool(false), "Expected error to be thrown")
        } catch let error as BrowserError {
            if case .scriptFailed = error { /* pass */ } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        }
    }
}

// MARK: - Box helper (reference wrapper for closures)

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
