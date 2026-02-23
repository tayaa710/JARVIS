import Testing
import Foundation
@testable import JARVIS

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    // Set before each test. Receives the request, returns (response, data) or throws.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    // Counts requests made during the test.
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.requestCount += 1
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

extension APIClientTests {
    /// A URLSessionConfiguration with MockURLProtocol registered.
    static func mockConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    static func response(statusCode: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }
}

// MARK: - Tests

// .serialized is required because MockURLProtocol uses static state shared across tests.
@Suite("APIClient Tests", .serialized)
struct APIClientTests {

    // Reset mock state before each test.
    init() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
    }

    // MARK: GET

    @Test func testGetRequest() async throws {
        let expectedData = Data("response body".utf8)
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.absoluteString == "https://example.com/path")
            return (APIClientTests.response(statusCode: 200), expectedData)
        }

        let client = APIClient(configuration: APIClientTests.mockConfiguration())
        let (data, resp) = try await client.get(url: "https://example.com/path", headers: [:])

        #expect(data == expectedData)
        #expect(resp.statusCode == 200)
    }

    // MARK: POST

    @Test func testPostRequest() async throws {
        let bodyData = Data("request body".utf8)
        let expectedData = Data("ok".utf8)
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.httpBodyStream != nil || request.httpBody != nil)
            return (APIClientTests.response(statusCode: 200), expectedData)
        }

        let client = APIClient(configuration: APIClientTests.mockConfiguration())
        let (data, resp) = try await client.post(url: "https://example.com/api", headers: [:], body: bodyData)

        #expect(data == expectedData)
        #expect(resp.statusCode == 200)
    }

    // MARK: Default headers merge

    @Test func testDefaultHeadersMerge() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.value(forHTTPHeaderField: "X-Default") == "default-value")
            #expect(request.value(forHTTPHeaderField: "X-PerCall") == "per-call-value")
            return (APIClientTests.response(statusCode: 200), Data())
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            defaultHeaders: ["X-Default": "default-value"]
        )
        _ = try await client.get(url: "https://example.com", headers: ["X-PerCall": "per-call-value"])
    }

    // MARK: HTTP error

    @Test func testHTTPErrorThrows() async throws {
        MockURLProtocol.requestHandler = { _ in
            (APIClientTests.response(statusCode: 404), Data("not found".utf8))
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 0
        )

        do {
            _ = try await client.get(url: "https://example.com", headers: [:])
            #expect(Bool(false), "Expected httpError to be thrown")
        } catch let error as APIClientError {
            if case .httpError(let code, _) = error {
                #expect(code == 404)
            } else {
                #expect(Bool(false), "Expected .httpError but got \(error)")
            }
        }
    }

    // MARK: Retry on 429

    @Test func testRetryOn429() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return (APIClientTests.response(statusCode: 429), Data())
            }
            return (APIClientTests.response(statusCode: 200), Data("ok".utf8))
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 3,
            baseRetryDelay: 0.0
        )
        let (_, resp) = try await client.get(url: "https://example.com", headers: [:])

        #expect(resp.statusCode == 200)
        #expect(callCount == 2)
    }

    // MARK: Retry on 500

    @Test func testRetryOn500() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return (APIClientTests.response(statusCode: 500), Data())
            }
            return (APIClientTests.response(statusCode: 200), Data("recovered".utf8))
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 3,
            baseRetryDelay: 0.0
        )
        let (_, resp) = try await client.get(url: "https://example.com", headers: [:])

        #expect(resp.statusCode == 200)
        #expect(callCount == 2)
    }

    // MARK: Max retries exhausted

    @Test func testMaxRetriesExhausted() async throws {
        MockURLProtocol.requestHandler = { _ in
            (APIClientTests.response(statusCode: 500), Data())
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 2,
            baseRetryDelay: 0.0
        )

        var threwError = false
        do {
            _ = try await client.get(url: "https://example.com", headers: [:])
        } catch {
            threwError = true
        }
        #expect(threwError)
        // 1 initial + 2 retries = 3 total requests
        #expect(MockURLProtocol.requestCount == 3)
    }

    // MARK: No retry on 400

    @Test func testNoRetryOn400() async throws {
        MockURLProtocol.requestHandler = { _ in
            (APIClientTests.response(statusCode: 400), Data())
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 3,
            baseRetryDelay: 0.0
        )

        do {
            _ = try await client.get(url: "https://example.com", headers: [:])
        } catch {}

        #expect(MockURLProtocol.requestCount == 1)
    }

    // MARK: Timeout

    @Test(.timeLimit(.minutes(1))) func testTimeout() async throws {
        MockURLProtocol.requestHandler = { _ in
            // Simulate a slow server by throwing a URLError timeout.
            throw URLError(.timedOut)
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            timeoutInterval: 0.001,
            maxRetries: 0
        )

        var threwError = false
        do {
            _ = try await client.get(url: "https://example.com", headers: [:])
        } catch {
            threwError = true
        }
        #expect(threwError)
    }

    // MARK: Streaming happy path

    @Test func testPostStreamingReturnsData() async throws {
        let responseBody = Data("chunk1chunk2".utf8)
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            return (APIClientTests.response(statusCode: 200), responseBody)
        }

        let client = APIClient(configuration: APIClientTests.mockConfiguration())
        var collected = Data()
        let stream = client.postStreaming(url: "https://example.com/stream", headers: [:], body: nil)
        for try await chunk in stream {
            collected.append(chunk)
        }
        #expect(!collected.isEmpty)
    }

    // MARK: Retry-After header

    @Test(.timeLimit(.minutes(1))) func testRetryAfterHeaderRespected() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                // Retry-After: 1 second
                return (APIClientTests.response(statusCode: 429, headers: ["Retry-After": "1"]), Data())
            }
            return (APIClientTests.response(statusCode: 200), Data("ok".utf8))
        }

        let client = APIClient(
            configuration: APIClientTests.mockConfiguration(),
            maxRetries: 3,
            baseRetryDelay: 0.0
        )

        let start = Date()
        let (_, resp) = try await client.get(url: "https://example.com", headers: [:])
        let elapsed = Date().timeIntervalSince(start)

        #expect(resp.statusCode == 200)
        #expect(elapsed >= 1.0)
    }
}
