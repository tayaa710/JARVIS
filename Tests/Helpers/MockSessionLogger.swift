import Foundation
@testable import JARVIS

// MARK: - MockSessionLogger

final class MockSessionLogger: SessionLogging, @unchecked Sendable {

    enum Event: Equatable {
        case userMessage(String)
        case thinkingRound(Int, Int, Int)
        case toolCall(String, String, RiskLevel, PolicyDecision)
        case toolResult(String, Bool)
        case toolDenied(String)
        case toolRejected(String)
        case assistantText(String)
        case metrics(Int, [String], Int)   // roundCount, toolsUsed, errorsEncountered
        case error(String)
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    var events: [Event] { lock.withLock { _events } }

    func logUserMessage(_ text: String) {
        lock.withLock { _events.append(.userMessage(text)) }
    }

    func logThinkingRound(_ round: Int, messageCount: Int, toolCount: Int) {
        lock.withLock { _events.append(.thinkingRound(round, messageCount, toolCount)) }
    }

    func logToolCall(name: String, inputJSON: String, risk: RiskLevel, decision: PolicyDecision) {
        lock.withLock { _events.append(.toolCall(name, inputJSON, risk, decision)) }
    }

    func logToolResult(name: String, isError: Bool, elapsed: TimeInterval, output: String) {
        lock.withLock { _events.append(.toolResult(name, isError)) }
    }

    func logToolDenied(name: String) {
        lock.withLock { _events.append(.toolDenied(name)) }
    }

    func logToolRejected(name: String) {
        lock.withLock { _events.append(.toolRejected(name)) }
    }

    func logAssistantText(_ text: String) {
        lock.withLock { _events.append(.assistantText(text)) }
    }

    func logMetrics(_ metrics: TurnMetrics) {
        lock.withLock { _events.append(.metrics(metrics.roundCount, metrics.toolsUsed, metrics.errorsEncountered)) }
    }

    func logError(_ message: String) {
        lock.withLock { _events.append(.error(message)) }
    }
}
