import Foundation
@testable import JARVIS

/// Mock WebSocket task for injecting into DeepgramWebSocketTransport.
final class MockWebSocketTask: WebSocketTaskProtocol {

    private(set) var resumeCalled = false
    private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []
    private(set) var cancelCalled = false
    private(set) var cancelCode: URLSessionWebSocketTask.CloseCode?

    // Queue of messages for receive() to return in order.
    var receiveQueue: [URLSessionWebSocketTask.Message] = []
    // Error to throw after queue is exhausted (nil = block forever, non-nil = throw).
    var receiveExhaustError: Error? = URLError(.networkConnectionLost)

    private var receiveIndex = 0

    func resume() {
        resumeCalled = true
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        sentMessages.append(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        if receiveIndex < receiveQueue.count {
            let msg = receiveQueue[receiveIndex]
            receiveIndex += 1
            return msg
        }
        if let error = receiveExhaustError {
            throw error
        }
        // Block until cancelled
        try await Task.sleep(nanoseconds: 60_000_000_000)
        throw URLError(.timedOut)
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        cancelCalled = true
        cancelCode = closeCode
    }

    // MARK: - Helpers

    var lastSentText: String? {
        for msg in sentMessages.reversed() {
            if case .string(let s) = msg { return s }
        }
        return nil
    }

    var lastSentData: Data? {
        for msg in sentMessages.reversed() {
            if case .data(let d) = msg { return d }
        }
        return nil
    }
}

/// Mock DeepgramTransporting — used in DeepgramSpeechInput tests.
final class MockDeepgramTransport: DeepgramTransporting {

    private(set) var connectCalled = false
    private(set) var connectedURL: URL?
    private(set) var connectedHeaders: [String: String] = [:]
    private(set) var sentData: [Data] = []
    private(set) var sentTexts: [String] = []
    private(set) var closeCalled = false

    // Continuation to push messages into the receive stream from tests.
    private var continuation: AsyncThrowingStream<DeepgramMessage, Error>.Continuation?

    var connectError: Error?

    func connect(url: URL, headers: [String: String]) async throws {
        if let error = connectError { throw error }
        connectCalled = true
        connectedURL = url
        connectedHeaders = headers
    }

    func send(data: Data) async throws {
        sentData.append(data)
    }

    func send(text: String) async throws {
        sentTexts.append(text)
    }

    func receive() -> AsyncThrowingStream<DeepgramMessage, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func close() async {
        closeCalled = true
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Test helpers

    func push(_ message: DeepgramMessage) {
        continuation?.yield(message)
    }

    func finishWithError(_ error: Error) {
        continuation?.finish(throwing: error)
        continuation = nil
    }
}
