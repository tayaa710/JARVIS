import Foundation
@testable import JARVIS

// MARK: - MockMCPTransport

/// Mock MCPTransporting for testing MCPClient without spawning real processes.
///
/// Usage:
/// 1. Enqueue response Data items via `enqueueResponse(_:)` before the client calls `receive()`.
/// 2. After the test runs, inspect `sentMessages` to verify what the client sent.
/// 3. Call `simulateCrash()` to make the next `receive()` throw `MCPError.serverCrashed`.
final class MockMCPTransport: MCPTransporting, @unchecked Sendable {

    // MARK: - State

    private let lock = NSLock()
    private var _isRunning = false
    private var continuation: AsyncStream<Result<Data, Error>>.Continuation?
    private let stream: AsyncStream<Result<Data, Error>>
    private var iterator: AsyncStream<Result<Data, Error>>.AsyncIterator

    // MARK: - Test Recording

    var sentMessages: [Data] = []

    // MARK: - Init

    init() {
        var cap: AsyncStream<Result<Data, Error>>.Continuation?
        stream = AsyncStream { c in cap = c }
        continuation = cap
        iterator = stream.makeAsyncIterator()
    }

    // MARK: - MCPTransporting

    var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    func start() async throws {
        lock.withLock { _isRunning = true }
    }

    func send(_ message: Data) async throws {
        guard isRunning else { throw MCPError.transportClosed }
        lock.withLock { sentMessages.append(message) }
    }

    func receive() async throws -> Data {
        guard var it = Optional(iterator) else {
            throw MCPError.transportClosed
        }
        guard let result = await it.next() else {
            throw MCPError.transportClosed
        }
        iterator = it
        switch result {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }

    func stop() {
        lock.withLock { _isRunning = false }
        continuation?.finish()
    }

    // MARK: - Test Helpers

    /// Enqueues a raw Data response for `receive()` to return.
    func enqueueResponse(_ data: Data) {
        continuation?.yield(.success(data))
    }

    /// Encodes a value as JSON and enqueues it as a response.
    func enqueueJSON<T: Encodable>(_ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        enqueueResponse(data)
    }

    /// Makes the next `receive()` throw `MCPError.serverCrashed` and sets `isRunning` to false.
    func simulateCrash() {
        lock.withLock { _isRunning = false }
        continuation?.yield(.failure(MCPError.serverCrashed))
        continuation?.finish()
    }

    /// Closes the stream so `receive()` throws `MCPError.transportClosed`.
    func simulateClose() {
        lock.withLock { _isRunning = false }
        continuation?.finish()
    }

    // MARK: - Sent Message Helpers

    /// Decodes the last sent message as a JSONRPCRequest.
    func lastSentRequest() -> JSONRPCRequest? {
        guard let last = lock.withLock({ sentMessages.last }) else { return nil }
        return try? JSONDecoder().decode(JSONRPCRequest.self, from: last)
    }

    /// Decodes the last sent message as a JSONRPCNotification.
    func lastSentNotification() -> JSONRPCNotification? {
        guard let last = lock.withLock({ sentMessages.last }) else { return nil }
        return try? JSONDecoder().decode(JSONRPCNotification.self, from: last)
    }

    /// Decodes all sent messages as JSONRPCRequests (skipping non-request messages).
    func allSentRequests() -> [JSONRPCRequest] {
        lock.withLock { sentMessages }
            .compactMap { try? JSONDecoder().decode(JSONRPCRequest.self, from: $0) }
    }

    /// Decodes all sent messages as JSONRPCNotifications (skipping non-notification messages).
    func allSentNotifications() -> [JSONRPCNotification] {
        lock.withLock { sentMessages }
            .compactMap { try? JSONDecoder().decode(JSONRPCNotification.self, from: $0) }
    }
}

// MARK: - MockMCPClient

/// Mock MCPClientProtocol for testing MCPToolAdapter without a real server.
final class MockMCPClient: MCPClientProtocol, @unchecked Sendable {

    var serverInfo: MCPServerInfo? = MCPServerInfo(name: "TestServer", version: "1.0")
    var isConnected: Bool = true

    var initializeResult: MCPServerInfo = MCPServerInfo(name: "TestServer", version: "1.0")
    var listToolsResult: [MCPTool] = []
    var callToolResult: MCPToolCallResult = MCPToolCallResult(content: [], isError: nil)
    var callToolError: Error? = nil

    private(set) var callToolCallCount = 0
    private(set) var lastCallToolName: String?
    private(set) var lastCallToolArguments: [String: JSONValue]?

    func initialize() async throws -> MCPServerInfo { initializeResult }

    func listTools() async throws -> [MCPTool] { listToolsResult }

    func callTool(name: String, arguments: [String: JSONValue]) async throws -> MCPToolCallResult {
        callToolCallCount += 1
        lastCallToolName = name
        lastCallToolArguments = arguments
        if let error = callToolError { throw error }
        return callToolResult
    }

    func shutdown() {
        isConnected = false
    }
}
