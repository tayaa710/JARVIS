// Placeholder types — fleshed out in M003 and M004.
// These exist solely so the Core protocols compile.

struct Message: Sendable, Codable {}
struct ToolDefinition: Sendable, Codable {}
struct Response: Sendable {}
struct StreamEvent: Sendable {}
struct ToolCall: Sendable {}
struct ToolResult: Sendable {}

enum RiskLevel: Sendable {
    case safe
    case caution
    case dangerous
    case destructive
}

enum PolicyDecision: Sendable {
    case allow
    case requireConfirmation
    case deny
}
