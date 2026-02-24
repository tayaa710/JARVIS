import Foundation
@testable import JARVIS

// MARK: - MockCDPTransport

/// Mock CDPTransport for testing CDPBackendImpl without a real WebSocket server.
///
/// Usage pattern:
/// 1. Set `enqueueAutoResponse` or call `enqueueResponse` before the backend sends a command.
/// 2. The background reader in CDPBackendImpl calls `receive()`, which blocks until data is enqueued.
final class MockCDPTransport: CDPTransport, @unchecked Sendable {

    // MARK: - Call Recording

    var sentMessages: [Data] = []
    var connectURL: URL?
    var disconnected: Bool = false
    var shouldFailConnect: Bool = false

    // MARK: - Async stream internals

    private var continuation: AsyncStream<Data>.Continuation?
    private let stream: AsyncStream<Data>
    private var iterator: AsyncStream<Data>.Iterator

    // MARK: - Init

    init() {
        var cap: AsyncStream<Data>.Continuation?
        stream = AsyncStream<Data> { continuation in
            cap = continuation
        }
        continuation = cap
        iterator = stream.makeAsyncIterator()
    }

    // MARK: - CDPTransport

    func connect(to url: URL) async throws {
        if shouldFailConnect {
            throw CDPError.connectionFailed("Mock connect failure")
        }
        connectURL = url
    }

    func send(_ data: Data) async throws {
        sentMessages.append(data)
    }

    func receive() async throws -> Data {
        guard let data = await iterator.next() else {
            throw CDPError.connectionClosed
        }
        return data
    }

    func disconnect() {
        disconnected = true
        continuation?.finish()
    }

    // MARK: - Test Helpers

    /// Enqueues raw data for `receive()` to return.
    func enqueueResponse(_ data: Data) {
        continuation?.yield(data)
    }

    /// Parses the `id` from a sent JSON command and enqueues a response with that id.
    /// Call this AFTER `send` would be called (or set up a side-effect in `send`).
    func enqueueResponseForLastSent(result: JSONValue = .string("ok")) {
        guard let last = sentMessages.last,
              let obj = try? JSONDecoder().decode(JSONValue.self, from: last),
              case .object(let dict) = obj,
              case .number(let idNum) = dict["id"] else {
            return
        }
        let id = Int(idNum)
        let response: [String: JSONValue] = [
            "id": .number(Double(id)),
            "result": result
        ]
        if let data = try? JSONEncoder().encode(JSONValue.object(response)) {
            continuation?.yield(data)
        }
    }

    /// Enqueues a CDP response JSON with the given id and result.
    func enqueueResponse(id: Int, result: JSONValue) {
        let response: [String: JSONValue] = [
            "id": .number(Double(id)),
            "result": result
        ]
        if let data = try? JSONEncoder().encode(JSONValue.object(response)) {
            continuation?.yield(data)
        }
    }

    /// Enqueues a CDP error response JSON with the given id.
    func enqueueErrorResponse(id: Int, message: String) {
        let response: [String: JSONValue] = [
            "id": .number(Double(id)),
            "error": .object(["message": .string(message)])
        ]
        if let data = try? JSONEncoder().encode(JSONValue.object(response)) {
            continuation?.yield(data)
        }
    }
}
