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
