import Foundation

// MARK: - Role

enum Role: String, Sendable, Codable {
    case user
    case assistant
}

// MARK: - ToolUse

struct ToolUse: Sendable, Codable, Equatable {
    let id: String
    let name: String
    let input: [String: JSONValue]
}

// MARK: - ToolResult

struct ToolResult: Sendable, Codable {
    let toolUseId: String
    let content: String
    let isError: Bool

    enum CodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }
}

// MARK: - ToolDefinition

struct ToolDefinition: Sendable, Codable {
    let name: String
    let description: String
    let inputSchema: JSONValue

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }
}

// MARK: - ContentBlock

enum ContentBlock: Sendable, Codable {
    case text(String)
    case toolUse(ToolUse)
    case toolResult(ToolResult)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: JSONValue].self, forKey: .input)
            self = .toolUse(ToolUse(id: id, name: name, input: input))
        case "tool_result":
            let toolUseId = try container.decode(String.self, forKey: .toolUseId)
            let content = try container.decode(String.self, forKey: .content)
            let isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            self = .toolResult(ToolResult(toolUseId: toolUseId, content: content, isError: isError))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ContentBlock type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let toolUse):
            try container.encode("tool_use", forKey: .type)
            try container.encode(toolUse.id, forKey: .id)
            try container.encode(toolUse.name, forKey: .name)
            try container.encode(toolUse.input, forKey: .input)
        case .toolResult(let result):
            try container.encode("tool_result", forKey: .type)
            try container.encode(result.toolUseId, forKey: .toolUseId)
            try container.encode(result.content, forKey: .content)
            try container.encode(result.isError, forKey: .isError)
        }
    }
}

// MARK: - Message

struct Message: Sendable, Codable {
    let role: Role
    let content: [ContentBlock]

    init(role: Role, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }

    /// Convenience for simple text messages.
    init(role: Role, text: String) {
        self.role = role
        self.content = [.text(text)]
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(Role.self, forKey: .role)
        // The API accepts content as either a plain string or an array of blocks.
        if let text = try? container.decode(String.self, forKey: .content) {
            self.content = [.text(text)]
        } else {
            self.content = try container.decode([ContentBlock].self, forKey: .content)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        // Use string shorthand when the message is a single text block.
        if content.count == 1, case .text(let text) = content[0] {
            try container.encode(text, forKey: .content)
        } else {
            try container.encode(content, forKey: .content)
        }
    }
}

// MARK: - StopReason

enum StopReason: String, Sendable, Codable {
    case endTurn = "end_turn"
    case toolUse = "tool_use"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
}

// MARK: - Usage

struct Usage: Sendable, Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    // Custom init to explicitly ignore extra fields such as
    // cache_creation_input_tokens that the API may return.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        self.outputTokens = try container.decode(Int.self, forKey: .outputTokens)
    }
}

// MARK: - Response

struct Response: Sendable, Codable {
    let id: String
    let model: String
    let content: [ContentBlock]
    let stopReason: StopReason?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case content
        case stopReason = "stop_reason"
        case usage
    }
}

// MARK: - StreamEvent

// Not Codable — constructed by AnthropicProvider from parsed SSE data.
enum StreamEvent: Sendable {
    case messageStart(id: String, model: String)
    case textDelta(String)
    case toolUseStart(index: Int, toolUse: ToolUse)
    case inputJSONDelta(index: Int, delta: String)
    case contentBlockStop(index: Int)
    case messageDelta(stopReason: StopReason, usage: Usage)
    case messageStop
    case ping
}

// MARK: - RiskLevel

enum RiskLevel: Sendable, Equatable {
    case safe
    case caution
    case dangerous
    case destructive
}

// MARK: - PolicyDecision

enum PolicyDecision: Sendable, Equatable {
    case allow
    case requireConfirmation
    case deny
}

// MARK: - AutonomyLevel

enum AutonomyLevel: Int, Sendable, Equatable {
    case askAll = 0       // Level 0 — confirm everything except safe
    case smartDefault = 1 // Level 1 — allow safe+caution, confirm dangerous+destructive
    case fullAuto = 2     // Level 2 — allow safe+caution+dangerous, confirm destructive
}
