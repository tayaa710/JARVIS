import Foundation

// MARK: - OrchestratorError

enum OrchestratorError: Error, Sendable {
    case maxRoundsExceeded
    case timeout
    case cancelled
    case noResponse
}

// MARK: - TurnMetrics

struct TurnMetrics: Sendable, Equatable {
    let roundCount: Int
    let elapsedTime: TimeInterval
    let toolsUsed: [String]
    let errorsEncountered: Int
    let inputTokens: Int
    let outputTokens: Int
}

// MARK: - OrchestratorResult

struct OrchestratorResult: Sendable, Equatable {
    let text: String
    let metrics: TurnMetrics
}

// MARK: - ContextLock

struct ContextLock: Sendable, Equatable {
    let bundleId: String
    let pid: Int32
}

// MARK: - ConfirmationHandler

typealias ConfirmationHandler = @Sendable (ToolUse) async -> Bool

// MARK: - Orchestrator Protocol

protocol Orchestrator: Sendable {
    func process(userMessage: String) async throws -> OrchestratorResult
    func reset()
    func abort()
    var contextLock: ContextLock? { get }
    func setContextLock(_ lock: ContextLock)
    func clearContextLock()
    var conversationHistory: [Message] { get }
}
