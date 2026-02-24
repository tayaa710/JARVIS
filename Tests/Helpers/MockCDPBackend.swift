import Foundation
@testable import JARVIS

// MARK: - MockCDPBackend

/// Configurable mock implementation of CDPBackendProtocol.
/// Prepared for M015 browser tool tests.
final class MockCDPBackend: CDPBackendProtocol, @unchecked Sendable {

    // MARK: - Configurable State

    var _isConnected: Bool = false
    var isConnected: Bool { _isConnected }

    // MARK: - Configurable Throw Errors (per method)

    var connectShouldThrow: CDPError?
    var navigateShouldThrow: CDPError?
    var evaluateJSShouldThrow: CDPError?
    var findElementShouldThrow: CDPError?
    var clickElementShouldThrow: CDPError?
    var typeInElementShouldThrow: CDPError?
    var getTextShouldThrow: CDPError?
    var getURLShouldThrow: CDPError?

    // MARK: - Configurable Return Values

    var navigateResult: String = "frame-1"
    var evaluateJSResult: String = ""
    var findElementResult: Bool = true
    var getTextResult: String = ""
    var getURLResult: String = "https://example.com"

    // MARK: - Call Recording

    var connectCallCount: Int = 0
    var disconnectCallCount: Int = 0
    var navigateCallCount: Int = 0
    var evaluateJSCallCount: Int = 0
    var findElementCallCount: Int = 0
    var clickElementCallCount: Int = 0
    var typeInElementCallCount: Int = 0
    var getTextCallCount: Int = 0
    var getURLCallCount: Int = 0

    var lastConnectPort: Int?
    var lastNavigateURL: String?
    var lastEvaluateJSExpression: String?
    var lastFindElementSelector: String?
    var lastClickElementSelector: String?
    var lastTypeInElementSelector: String?
    var lastTypeInElementText: String?

    // MARK: - CDPBackendProtocol

    func connect(port: Int) async throws {
        connectCallCount += 1
        lastConnectPort = port
        if let error = connectShouldThrow { throw error }
        _isConnected = true
    }

    func disconnect() async {
        disconnectCallCount += 1
        _isConnected = false
    }

    func navigate(url: String) async throws -> String {
        navigateCallCount += 1
        lastNavigateURL = url
        if let error = navigateShouldThrow { throw error }
        return navigateResult
    }

    func evaluateJS(_ expression: String) async throws -> String {
        evaluateJSCallCount += 1
        lastEvaluateJSExpression = expression
        if let error = evaluateJSShouldThrow { throw error }
        return evaluateJSResult
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

    func getText() async throws -> String {
        getTextCallCount += 1
        if let error = getTextShouldThrow { throw error }
        return getTextResult
    }

    func getURL() async throws -> String {
        getURLCallCount += 1
        if let error = getURLShouldThrow { throw error }
        return getURLResult
    }
}
