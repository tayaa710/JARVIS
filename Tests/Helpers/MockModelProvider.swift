import Foundation
@testable import JARVIS

// MockModelProvider queues scripted responses for integration tests.
// Crashes loudly (fatalError) when the queue is empty — this is a developer error.
final class MockModelProvider: ModelProvider, @unchecked Sendable {

    private var responses: [Response] = []
    private var streamEventQueues: [[StreamEvent]] = []

    private(set) var sendCallCount: Int = 0
    private(set) var lastMessages: [Message]?
    private(set) var lastTools: [ToolDefinition]?
    private(set) var lastSystem: String?
    private(set) var abortCalled: Bool = false

    private let lock = NSLock()

    func enqueue(response: Response) {
        lock.withLock { responses.append(response) }
    }

    func enqueueStream(events: [StreamEvent]) {
        lock.withLock { streamEventQueues.append(events) }
    }

    func send(messages: [Message], tools: [ToolDefinition], system: String?) async throws -> Response {
        return lock.withLock {
            sendCallCount += 1
            lastMessages = messages
            lastTools = tools
            lastSystem = system
            guard !responses.isEmpty else {
                fatalError("MockModelProvider: response queue is empty (sendCallCount=\(sendCallCount))")
            }
            return responses.removeFirst()
        }
    }

    func sendStreaming(messages: [Message], tools: [ToolDefinition], system: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        let events = lock.withLock { () -> [StreamEvent] in
            lastMessages = messages
            lastTools = tools
            lastSystem = system
            guard !streamEventQueues.isEmpty else {
                fatalError("MockModelProvider: stream queue is empty")
            }
            return streamEventQueues.removeFirst()
        }

        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func abort() {
        lock.withLock { abortCalled = true }
    }
}
