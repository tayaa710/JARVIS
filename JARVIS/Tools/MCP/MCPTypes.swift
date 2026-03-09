import Foundation

// MARK: - Protocol Version

let MCPProtocolVersion = "2025-11-25"

// MARK: - JSONRPCRequest

struct JSONRPCRequest: Sendable, Codable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: JSONValue?

    init(id: Int, method: String, params: JSONValue?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        if let params {
            try container.encode(params, forKey: .params)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
}

// MARK: - JSONRPCResponse

struct JSONRPCResponse: Sendable, Codable {
    let jsonrpc: String
    let id: Int?
    let result: JSONValue?
    let error: JSONRPCError?
}

// MARK: - JSONRPCError

struct JSONRPCError: Sendable, Codable {
    let code: Int
    let message: String
    let data: JSONValue?
}

// MARK: - JSONRPCNotification

struct JSONRPCNotification: Sendable, Codable {
    let jsonrpc: String
    let method: String
    let params: JSONValue?

    init(method: String, params: JSONValue?) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        if let params {
            try container.encode(params, forKey: .params)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params
    }
}

// MARK: - MCPClientInfo

struct MCPClientInfo: Sendable, Codable {
    let name: String
    let version: String
}

// MARK: - MCPServerInfo

struct MCPServerInfo: Sendable, Codable {
    let name: String
    let version: String
}

// MARK: - MCPServerCapabilities

struct MCPToolsCapability: Sendable, Codable {
    let listChanged: Bool?
}

struct MCPServerCapabilities: Sendable, Codable {
    let tools: MCPToolsCapability?
}

// MARK: - MCPTool

struct MCPTool: Sendable, Codable {
    let name: String
    let description: String?
    let inputSchema: JSONValue
}

// MARK: - MCPContent

enum MCPContent: Sendable, Codable {
    case text(String)
    case image(data: String, mimeType: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, data, mimeType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            self = .image(data: data, mimeType: mimeType)
        default:
            // Treat unknown content types as empty text to be forward-compatible
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data, let mimeType):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
        }
    }
}

// MARK: - MCPToolCallResult

struct MCPToolCallResult: Sendable, Codable {
    let content: [MCPContent]
    let isError: Bool?
}

// MARK: - MCPError

enum MCPError: Error, Sendable, Equatable {
    case transportClosed
    case handshakeFailed(String)
    case serverError(code: Int, message: String)
    case timeout
    case decodingFailed(String)
    case serverCrashed

    static func == (lhs: MCPError, rhs: MCPError) -> Bool {
        switch (lhs, rhs) {
        case (.transportClosed, .transportClosed): return true
        case (.handshakeFailed(let a), .handshakeFailed(let b)): return a == b
        case (.serverError(let c1, let m1), .serverError(let c2, let m2)): return c1 == c2 && m1 == m2
        case (.timeout, .timeout): return true
        case (.decodingFailed(let a), .decodingFailed(let b)): return a == b
        case (.serverCrashed, .serverCrashed): return true
        default: return false
        }
    }
}
