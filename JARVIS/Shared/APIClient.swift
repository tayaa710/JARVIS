import Foundation

// MARK: - Errors

public enum APIClientError: Error, Equatable {
    case invalidURL
    case httpError(statusCode: Int, body: Data?)
    case networkError(String) // wraps underlying error description
    case timeout
    case decodingError(String)

    public static func == (lhs: APIClientError, rhs: APIClientError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.httpError(let a, let b), .httpError(let c, let d)): return a == c && b == d
        case (.networkError(let a), .networkError(let b)): return a == b
        case (.timeout, .timeout): return true
        case (.decodingError(let a), .decodingError(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Protocol

public protocol APIClientProtocol: Sendable {
    func get(url: String, headers: [String: String]) async throws -> (Data, HTTPURLResponse)
    func post(url: String, headers: [String: String], body: Data?) async throws -> (Data, HTTPURLResponse)
    func postStreaming(url: String, headers: [String: String], body: Data?) -> AsyncThrowingStream<Data, Error>
}

// MARK: - Implementation

public final class APIClient: APIClientProtocol {
    private let session: URLSession
    public let defaultHeaders: [String: String]
    public let timeoutInterval: TimeInterval
    public let maxRetries: Int
    public let baseRetryDelay: TimeInterval

    public init(
        configuration: URLSessionConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        timeoutInterval: TimeInterval = 60,
        maxRetries: Int = 3,
        baseRetryDelay: TimeInterval = 1.0
    ) {
        self.session = URLSession(configuration: configuration)
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
    }

    // MARK: - GET

    public func get(url: String, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        let request = try buildRequest(url: url, method: "GET", headers: headers, body: nil)
        return try await performWithRetry(request: request)
    }

    // MARK: - POST

    public func post(url: String, headers: [String: String], body: Data?) async throws -> (Data, HTTPURLResponse) {
        let request = try buildRequest(url: url, method: "POST", headers: headers, body: body)
        return try await performWithRetry(request: request)
    }

    // MARK: - POST Streaming

    public func postStreaming(url: String, headers: [String: String], body: Data?) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(url: url, method: "POST", headers: headers, body: body)
                    let start = Date()
                    Logger.api.info("Stream open: POST \(url)")

                    let (asyncBytes, response) = try await self.session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIClientError.networkError("Non-HTTP response"))
                        return
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: APIClientError.httpError(statusCode: httpResponse.statusCode, body: nil))
                        return
                    }

                    var buffer = Data()
                    for try await byte in asyncBytes {
                        buffer.append(byte)
                        // Yield in chunks — flush whenever we have data available.
                        if buffer.count >= 1 {
                            continuation.yield(buffer)
                            buffer = Data()
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }

                    let elapsed = Date().timeIntervalSince(start)
                    Logger.api.info("Stream closed: POST \(url), elapsed \(String(format: "%.3f", elapsed))s")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildRequest(url: String, method: String, headers: [String: String], body: Data?) throws -> URLRequest {
        guard let parsedURL = URL(string: url) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: parsedURL, timeoutInterval: timeoutInterval)
        request.httpMethod = method

        // Apply default headers first, then per-call headers (per-call wins on conflict).
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = body
        }

        return request
    }

    private func performWithRetry(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url?.absoluteString ?? "unknown"
        var attempt = 0

        while true {
            let start = Date()
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIClientError.networkError("Non-HTTP response")
                }

                let elapsed = Date().timeIntervalSince(start)
                Logger.api.info("\(request.httpMethod ?? "?") \(url) → \(httpResponse.statusCode) (\(String(format: "%.3f", elapsed))s)")

                let status = httpResponse.statusCode

                if (200..<300).contains(status) {
                    return (data, httpResponse)
                }

                // Retry on 429 or 5xx.
                if status == 429 || (500...599).contains(status) {
                    if attempt < maxRetries {
                        let delay = retryDelay(attempt: attempt, response: httpResponse)
                        Logger.api.warning("Retrying \(url) (attempt \(attempt + 1)/\(maxRetries)) after \(String(format: "%.1f", delay))s, status: \(status)")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                }

                // Non-retryable or retries exhausted.
                throw APIClientError.httpError(statusCode: status, body: data)

            } catch let error as APIClientError {
                throw error
            } catch let urlError as URLError {
                if urlError.code == .timedOut {
                    Logger.api.error("Request timed out: \(url)")
                    throw APIClientError.timeout
                }
                Logger.api.error("Network error for \(url): \(urlError.localizedDescription)")
                throw APIClientError.networkError(urlError.localizedDescription)
            } catch {
                Logger.api.error("Unexpected error for \(url): \(error.localizedDescription)")
                throw APIClientError.networkError(error.localizedDescription)
            }
        }
    }

    private func retryDelay(attempt: Int, response: HTTPURLResponse) -> TimeInterval {
        // Respect Retry-After header on 429.
        if response.statusCode == 429,
           let retryAfterValue = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfterSeconds = TimeInterval(retryAfterValue) {
            return retryAfterSeconds
        }
        // Exponential backoff: baseRetryDelay * 2^attempt
        return baseRetryDelay * pow(2.0, Double(attempt))
    }
}
