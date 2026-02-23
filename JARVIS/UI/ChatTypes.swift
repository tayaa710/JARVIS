import Foundation

// MARK: - AssistantStatus

enum AssistantStatus: Equatable {
    case idle
    case thinking
    case executingTool(String)
    case speaking
}

// MARK: - ToolCallStatus

enum ToolCallStatus: Equatable {
    case running
    case completed
    case failed
}

// MARK: - ToolCallInfo

struct ToolCallInfo: Identifiable, Equatable {
    let id: String
    var name: String
    var status: ToolCallStatus
    var result: String?
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var text: String
    let timestamp: Date
    var toolCalls: [ToolCallInfo]
    var isStreaming: Bool
}

// MARK: - PendingConfirmation

struct PendingConfirmation: Identifiable {
    let id: UUID
    let toolUse: ToolUse
    let continuation: CheckedContinuation<Bool, Never>
}
