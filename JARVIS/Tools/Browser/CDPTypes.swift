import Foundation

// MARK: - CDPError

/// Errors produced by the CDP backend layer.
public enum CDPError: Error, Equatable {
    case connectionFailed(String)
    case commandTimeout(String)
    case invalidResponse(String)
    case evaluationError(String)
    case notConnected
    case discoveryFailed(String)
    case noTargetsFound
    case connectionClosed
}

// MARK: - CDPError + LocalizedError

extension CDPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            return "CDP connection failed: \(detail). Ensure the browser is running. If using Chrome DevTools Protocol, Chrome must be launched with --remote-debugging-port=9222."
        case .commandTimeout(let command):
            return "CDP command timed out: \(command). The browser may be unresponsive."
        case .invalidResponse(let detail):
            return "CDP received an invalid response: \(detail)."
        case .evaluationError(let detail):
            return "JavaScript evaluation error: \(detail)."
        case .notConnected:
            return "Not connected to the browser via CDP. The browser may not have remote debugging enabled."
        case .discoveryFailed(let detail):
            return "CDP target discovery failed: \(detail). Is the browser running with --remote-debugging-port=9222?"
        case .noTargetsFound:
            return "No browser tabs found via CDP. Open a tab in the browser first."
        case .connectionClosed:
            return "CDP connection was closed. The browser tab may have been closed or navigated away."
        }
    }
}

// MARK: - CDPTarget

/// Represents a debug target returned by Chrome's /json endpoint.
public struct CDPTarget: Sendable, Equatable, Decodable {
    public let id: String
    public let title: String
    public let url: String
    public let webSocketDebuggerUrl: String
    public let type: String

    public init(id: String, title: String, url: String, webSocketDebuggerUrl: String, type: String) {
        self.id = id
        self.title = title
        self.url = url
        self.webSocketDebuggerUrl = webSocketDebuggerUrl
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case webSocketDebuggerUrl
        case type
    }
}
