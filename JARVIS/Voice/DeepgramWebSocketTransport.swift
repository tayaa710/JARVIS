import Foundation

// MARK: - WebSocketTaskProtocol

public protocol WebSocketTaskProtocol: AnyObject {
    func resume()
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: WebSocketTaskProtocol {}

// MARK: - DeepgramTransporting

public protocol DeepgramTransporting: AnyObject {
    func connect(url: URL, headers: [String: String]) async throws
    func send(data: Data) async throws
    func send(text: String) async throws
    func receive() -> AsyncThrowingStream<DeepgramMessage, Error>
    func close() async
}

// MARK: - DeepgramWebSocketTransport

public final class DeepgramWebSocketTransport: DeepgramTransporting {

    public typealias TaskFactory = (URLRequest) -> any WebSocketTaskProtocol

    private var task: (any WebSocketTaskProtocol)?
    private let taskFactory: TaskFactory

    // MARK: - Init

    public convenience init(session: URLSession = URLSession(configuration: .default)) {
        self.init(taskFactory: { request in
            session.webSocketTask(with: request)
        })
    }

    public init(taskFactory: @escaping TaskFactory) {
        self.taskFactory = taskFactory
    }

    // MARK: - DeepgramTransporting

    public func connect(url: URL, headers: [String: String]) async throws {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let task = taskFactory(request)
        self.task = task
        task.resume()
    }

    public func send(data: Data) async throws {
        try await task?.send(.data(data))
    }

    public func send(text: String) async throws {
        try await task?.send(.string(text))
    }

    public func receive() -> AsyncThrowingStream<DeepgramMessage, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let task = self.task else {
                    continuation.finish()
                    return
                }
                do {
                    while true {
                        let message = try await task.receive()
                        switch message {
                        case .string(let text):
                            continuation.yield(Self.parseMessage(text))
                        case .data(let data):
                            if let text = String(data: data, encoding: .utf8) {
                                continuation.yield(Self.parseMessage(text))
                            }
                        @unknown default:
                            break
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func close() async {
        let closeText = #"{"type":"CloseStream"}"#
        try? await task?.send(.string(closeText))
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    // MARK: - Message Parsing

    static func parseMessage(_ text: String) -> DeepgramMessage {
        guard let data = text.data(using: .utf8) else { return .unknown(text) }

        guard let raw = try? JSONDecoder().decode(DeepgramRawMessage.self, from: data) else {
            return .unknown(text)
        }

        switch raw.type {
        case "Results":
            guard let response = try? JSONDecoder().decode(DeepgramTranscriptResponse.self, from: data) else {
                return .unknown(text)
            }
            return .results(response)
        case "UtteranceEnd":
            return .utteranceEnd
        case "SpeechStarted":
            return .speechStarted
        case "Metadata":
            return .metadata
        case "Error":
            return .error(raw.message ?? "Unknown Deepgram error")
        default:
            return .unknown(raw.type)
        }
    }
}
