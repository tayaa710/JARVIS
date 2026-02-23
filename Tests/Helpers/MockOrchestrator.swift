import Foundation
@testable import JARVIS

// MockOrchestrator is a configurable Orchestrator for ChatViewModel tests.
final class MockOrchestrator: Orchestrator, @unchecked Sendable {

    var streamingEvents: [OrchestratorEvent] = []
    var processResult: OrchestratorResult = OrchestratorResult(
        text: "Mock response",
        metrics: TurnMetrics(
            roundCount: 1,
            elapsedTime: 0.1,
            toolsUsed: [],
            errorsEncountered: 0,
            inputTokens: 10,
            outputTokens: 5
        )
    )
    var shouldThrow: Error?

    private(set) var abortCalled = false
    private(set) var processCallCount = 0
    private(set) var lastUserMessage: String?

    private var _conversationHistory: [Message] = []
    private var _contextLock: ContextLock?
    private let lock = NSLock()

    var contextLock: ContextLock? { lock.withLock { _contextLock } }
    func setContextLock(_ lock: ContextLock) { self.lock.withLock { _contextLock = lock } }
    func clearContextLock() { lock.withLock { _contextLock = nil } }
    func reset() { lock.withLock { _conversationHistory = [] } }
    var conversationHistory: [Message] { lock.withLock { _conversationHistory } }

    func abort() {
        lock.withLock { abortCalled = true }
    }

    func process(userMessage: String) async throws -> OrchestratorResult {
        lock.withLock {
            processCallCount += 1
            lastUserMessage = userMessage
        }
        if let error = shouldThrow { throw error }
        return processResult
    }

    func processWithStreaming(
        userMessage: String,
        onEvent: @escaping OrchestratorEventHandler
    ) async throws -> OrchestratorResult {
        lock.withLock {
            processCallCount += 1
            lastUserMessage = userMessage
        }
        if let error = shouldThrow { throw error }
        let events = lock.withLock { streamingEvents }
        for event in events {
            onEvent(event)
        }
        return processResult
    }
}
