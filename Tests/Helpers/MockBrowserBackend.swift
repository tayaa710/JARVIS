import Foundation
@testable import JARVIS

// MARK: - MockBrowserBackend

/// Configurable mock implementation of BrowserBackend.
/// Used by browser tool tests in M015.
final class MockBrowserBackend: BrowserBackend, @unchecked Sendable {

    // MARK: - Configurable Errors (per method)

    var navigateShouldThrow: Error?
    var getURLShouldThrow: Error?
    var getTextShouldThrow: Error?
    var findElementShouldThrow: Error?
    var clickElementShouldThrow: Error?
    var typeInElementShouldThrow: Error?
    var evaluateJSShouldThrow: Error?

    // MARK: - Configurable Return Values

    var getURLResult: String = "https://example.com"
    var getTextResult: String = "Page text content"
    var findElementResult: Bool = true
    var evaluateJSResult: String = ""

    // MARK: - Call Recording

    var navigateCallCount: Int = 0
    var getURLCallCount: Int = 0
    var getTextCallCount: Int = 0
    var findElementCallCount: Int = 0
    var clickElementCallCount: Int = 0
    var typeInElementCallCount: Int = 0
    var evaluateJSCallCount: Int = 0

    var lastNavigateURL: String?
    var lastFindElementSelector: String?
    var lastClickElementSelector: String?
    var lastTypeInElementSelector: String?
    var lastTypeInElementText: String?
    var lastEvaluateJSExpression: String?

    // MARK: - BrowserBackend

    func navigate(url: String) async throws {
        navigateCallCount += 1
        lastNavigateURL = url
        if let error = navigateShouldThrow { throw error }
    }

    func getURL() async throws -> String {
        getURLCallCount += 1
        if let error = getURLShouldThrow { throw error }
        return getURLResult
    }

    func getText() async throws -> String {
        getTextCallCount += 1
        if let error = getTextShouldThrow { throw error }
        return getTextResult
    }

    func findElement(selector: String) async throws -> Bool {
        findElementCallCount += 1
        lastFindElementSelector = selector
        if let error = findElementShouldThrow { throw error }
        return findElementResult
    }

    func clickElement(selector: String) async throws {
        clickElementCallCount += 1
        lastClickElementSelector = selector
        if let error = clickElementShouldThrow { throw error }
    }

    func typeInElement(selector: String, text: String) async throws {
        typeInElementCallCount += 1
        lastTypeInElementSelector = selector
        lastTypeInElementText = text
        if let error = typeInElementShouldThrow { throw error }
    }

    func evaluateJS(_ expression: String) async throws -> String {
        evaluateJSCallCount += 1
        lastEvaluateJSExpression = expression
        if let error = evaluateJSShouldThrow { throw error }
        return evaluateJSResult
    }
}
