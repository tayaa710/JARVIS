import Foundation
@testable import JARVIS

// MockAPIClient captures requests and returns scripted responses.
// Configure postError to make all post() calls throw.
// Set blockPost = true to make post() sleep until task-cancelled (for abort tests).
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    // Captured request values.
    private(set) var lastPostURL: String?
    private(set) var lastPostHeaders: [String: String]?
    private(set) var lastPostBody: Data?

    // Queued responses (dequeued FIFO).
    var postResponses: [(Data, HTTPURLResponse)] = []
    var postStreamResponses: [AsyncThrowingStream<Data, Error>] = []

    // Error to throw on next post() call.
    var postError: Error?

    // When true, post() blocks until the calling task is cancelled.
    var blockPost = false

    private static let dummyURL = URL(string: "https://api.anthropic.com/v1/messages")!

    func get(url: String, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        fatalError("MockAPIClient.get() not implemented")
    }

    func post(url: String, headers: [String: String], body: Data?) async throws -> (Data, HTTPURLResponse) {
        lastPostURL = url
        lastPostHeaders = headers
        lastPostBody = body

        if let error = postError {
            throw error
        }

        if blockPost {
            // Sleep indefinitely — will be interrupted by task cancellation.
            try await Task.sleep(for: .seconds(60))
        }

        guard !postResponses.isEmpty else {
            fatalError("MockAPIClient: no queued post() response")
        }
        return postResponses.removeFirst()
    }

    func postStreaming(url: String, headers: [String: String], body: Data?) -> AsyncThrowingStream<Data, Error> {
        lastPostURL = url
        lastPostHeaders = headers
        lastPostBody = body

        guard !postStreamResponses.isEmpty else {
            fatalError("MockAPIClient: no queued postStreaming() response")
        }
        return postStreamResponses.removeFirst()
    }

    // MARK: - Helpers

    func enqueueJSONResponse(data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: Self.dummyURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        postResponses.append((data, response))
    }

    func enqueueFixtureStream(_ text: String) {
        let data = text.data(using: .utf8)!
        let stream = AsyncThrowingStream<Data, Error> { continuation in
            continuation.yield(data)
            continuation.finish()
        }
        postStreamResponses.append(stream)
    }
}
