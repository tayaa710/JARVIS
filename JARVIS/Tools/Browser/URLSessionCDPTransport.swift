import Foundation

// MARK: - URLSessionCDPTransport

/// Production CDPTransport implementation backed by URLSessionWebSocketTask.
///
/// Not unit tested — requires a real WebSocket server. Tested manually against
/// Chrome running with --remote-debugging-port=9222.
public final class URLSessionCDPTransport: CDPTransport, @unchecked Sendable {

    private let session: URLSession
    private let lock = NSLock()
    private var task: URLSessionWebSocketTask?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(to url: URL) async throws {
        let webSocketTask = session.webSocketTask(with: url)
        lock.lock()
        task = webSocketTask
        lock.unlock()
        webSocketTask.resume()
    }

    public func send(_ data: Data) async throws {
        lock.lock()
        let currentTask = task
        lock.unlock()
        guard let currentTask else {
            throw CDPError.notConnected
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw CDPError.invalidResponse("Cannot encode data as UTF-8")
        }
        try await currentTask.send(.string(string))
    }

    public func receive() async throws -> Data {
        lock.lock()
        let currentTask = task
        lock.unlock()
        guard let currentTask else {
            throw CDPError.notConnected
        }
        let message = try await currentTask.receive()
        switch message {
        case .string(let string):
            guard let data = string.data(using: .utf8) else {
                throw CDPError.invalidResponse("Cannot decode WebSocket string as UTF-8")
            }
            return data
        case .data(let data):
            return data
        @unknown default:
            throw CDPError.invalidResponse("Unknown WebSocket message type")
        }
    }

    public func disconnect() {
        lock.lock()
        let currentTask = task
        task = nil
        lock.unlock()
        currentTask?.cancel(with: .normalClosure, reason: nil)
    }
}
