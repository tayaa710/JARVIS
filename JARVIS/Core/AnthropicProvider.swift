import Foundation

// MARK: - Error

enum AnthropicError: Error, Equatable {
    case unauthorized
    case rateLimited
    case serverError(Int)
    case invalidResponse(String)
    case cancelled
}

// MARK: - AnthropicProvider

final class AnthropicProvider: ModelProvider, @unchecked Sendable {

    private let apiClient: APIClientProtocol
    private let apiKey: String
    private let model: String
    private let maxTokens: Int
    private let apiVersion: String

    // Stored cancel handle — set while a request is in flight, cleared on completion.
    private var cancelToken: (() -> Void)?
    private let lock = NSLock()

    private static let messagesURL = "https://api.anthropic.com/v1/messages"

    init(
        apiClient: APIClientProtocol,
        apiKey: String,
        model: String = "claude-opus-4-6",
        maxTokens: Int = 4096,
        apiVersion: String = "2023-06-01"
    ) {
        self.apiClient = apiClient
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.apiVersion = apiVersion
    }

    // MARK: - ModelProvider

    func send(messages: [Message], tools: [ToolDefinition], system: String?) async throws -> Response {
        let requestBody = try buildRequestBody(messages: messages, tools: tools, system: system, stream: false)
        let headers = buildHeaders()

        Logger.api.info("AnthropicProvider.send: model=\(self.model), messages=\(messages.count), tools=\(tools.count)")

        let task = Task<Response, Error> {
            do {
                let (data, httpResponse) = try await self.apiClient.post(
                    url: Self.messagesURL,
                    headers: headers,
                    body: requestBody
                )
                try self.checkHTTPStatus(httpResponse)

                do {
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    Logger.api.info(
                        "AnthropicProvider.send response: stop_reason=\(response.stopReason?.rawValue ?? "nil"), " +
                        "input_tokens=\(response.usage.inputTokens), output_tokens=\(response.usage.outputTokens)"
                    )
                    return response
                } catch let decodeError {
                    throw AnthropicError.invalidResponse("Decode failed: \(decodeError)")
                }
            } catch let e as AnthropicError {
                throw e
            } catch is CancellationError {
                throw AnthropicError.cancelled
            } catch let apiError as APIClientError {
                throw mapAPIClientError(apiError)
            }
        }

        lock.lock()
        cancelToken = { task.cancel() }
        lock.unlock()

        defer {
            lock.lock()
            cancelToken = nil
            lock.unlock()
        }

        do {
            return try await task.value
        } catch is CancellationError {
            throw AnthropicError.cancelled
        }
    }

    func sendStreaming(messages: [Message], tools: [ToolDefinition], system: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { [self] continuation in
            let task = Task {
                do {
                    let requestBody = try self.buildRequestBody(
                        messages: messages,
                        tools: tools,
                        system: system,
                        stream: true
                    )
                    let headers = self.buildHeaders()

                    Logger.api.info(
                        "AnthropicProvider.sendStreaming: model=\(self.model), " +
                        "messages=\(messages.count), tools=\(tools.count)"
                    )

                    let rawStream = self.apiClient.postStreaming(
                        url: Self.messagesURL,
                        headers: headers,
                        body: requestBody
                    )
                    let sseStream = SSEParser.parse(stream: rawStream)

                    // Accumulate input_json_delta partials keyed by content block index.
                    var partialInputJSON: [Int: String] = [:]

                    for try await sseEvent in sseStream {
                        if Task.isCancelled {
                            continuation.finish(throwing: AnthropicError.cancelled)
                            return
                        }

                        guard let streamEvent = try self.mapSSEEvent(sseEvent, partialInputJSON: &partialInputJSON) else {
                            continue
                        }
                        continuation.yield(streamEvent)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AnthropicError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            self.lock.lock()
            self.cancelToken = { task.cancel() }
            self.lock.unlock()
        }
    }

    func abort() {
        lock.lock()
        let token = cancelToken
        lock.unlock()
        token?()
    }

    // MARK: - Private

    private func buildRequestBody(
        messages: [Message],
        tools: [ToolDefinition],
        system: String?,
        stream: Bool
    ) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": try toJSONArray(messages),
            "stream": stream
        ]
        if let system {
            body["system"] = system
        }
        if !tools.isEmpty {
            body["tools"] = try toJSONArray(tools)
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func toJSONArray<T: Encodable>(_ items: [T]) throws -> [[String: Any]] {
        let encoder = JSONEncoder()
        return try items.map { item in
            let data = try encoder.encode(item)
            return try JSONSerialization.jsonObject(with: data) as! [String: Any]
        }
    }

    private func buildHeaders() -> [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": apiVersion,
            "content-type": "application/json"
        ]
    }

    private func checkHTTPStatus(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300: return
        case 401:        throw AnthropicError.unauthorized
        case 429:        throw AnthropicError.rateLimited
        default:         throw AnthropicError.serverError(response.statusCode)
        }
    }

    private func mapAPIClientError(_ error: APIClientError) -> AnthropicError {
        switch error {
        case .httpError(let status, _):
            switch status {
            case 401: return .unauthorized
            case 429: return .rateLimited
            default:  return .serverError(status)
            }
        default:
            return .invalidResponse(error.localizedDescription)
        }
    }

    private func mapSSEEvent(
        _ sseEvent: SSEEvent,
        partialInputJSON: inout [Int: String]
    ) throws -> StreamEvent? {
        guard let rawData = sseEvent.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any]
        else { return nil }

        switch sseEvent.event {
        case "message_start":
            guard let message = json["message"] as? [String: Any],
                  let id = message["id"] as? String,
                  let model = message["model"] as? String
            else { return nil }
            return .messageStart(id: id, model: model)

        case "content_block_start":
            guard let index = json["index"] as? Int,
                  let block = json["content_block"] as? [String: Any],
                  let type = block["type"] as? String,
                  type == "tool_use",
                  let id = block["id"] as? String,
                  let name = block["name"] as? String
            else { return nil }
            partialInputJSON[index] = ""
            return .toolUseStart(index: index, toolUse: ToolUse(id: id, name: name, input: [:]))

        case "content_block_delta":
            guard let index = json["index"] as? Int,
                  let delta = json["delta"] as? [String: Any],
                  let deltaType = delta["type"] as? String
            else { return nil }

            if deltaType == "text_delta", let text = delta["text"] as? String {
                return .textDelta(text)
            } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                partialInputJSON[index, default: ""] += partial
                return .inputJSONDelta(index: index, delta: partial)
            }
            return nil

        case "content_block_stop":
            guard let index = json["index"] as? Int else { return nil }
            return .contentBlockStop(index: index)

        case "message_delta":
            guard let delta = json["delta"] as? [String: Any],
                  let stopReasonStr = delta["stop_reason"] as? String,
                  let stopReason = StopReason(rawValue: stopReasonStr),
                  let usageJSON = json["usage"] as? [String: Any],
                  let outputTokens = usageJSON["output_tokens"] as? Int
            else { return nil }
            return .messageDelta(stopReason: stopReason, usage: Usage(inputTokens: 0, outputTokens: outputTokens))

        case "message_stop":
            return .messageStop

        case "ping":
            return .ping

        default:
            return nil
        }
    }
}
