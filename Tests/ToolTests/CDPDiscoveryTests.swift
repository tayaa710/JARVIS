import Testing
import Foundation
@testable import JARVIS

// MARK: - CDPDiscovery Tests
//
// Uses a custom URLProtocol to intercept HTTP requests to localhost:9222/json
// without requiring a real browser running with --remote-debugging-port.

// MARK: - MockCDPURLProtocol

final class MockCDPURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockCDPURLProtocol.requestHandler else {
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

extension CDPDiscoveryTests {
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockCDPURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func jsonResponse(statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "http://localhost:9222/json")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    static func sampleTarget(type: String = "page") -> CDPTarget {
        CDPTarget(
            id: "abc123",
            title: "Example",
            url: "https://example.com",
            webSocketDebuggerUrl: "ws://localhost:9222/devtools/page/abc123",
            type: type
        )
    }
}

// MARK: - Tests

@Suite("CDPDiscovery Tests", .serialized)
struct CDPDiscoveryTests {

    init() {
        MockCDPURLProtocol.requestHandler = nil
    }

    // MARK: discoverTargets

    @Test func testDiscoverTargetsParsesValidJSON() async throws {
        let target = CDPDiscoveryTests.sampleTarget()
        let json = """
        [{"id":"abc123","title":"Example","url":"https://example.com",
          "webSocketDebuggerUrl":"ws://localhost:9222/devtools/page/abc123","type":"page"}]
        """
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data(json.utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        let targets = try await discovery.discoverTargets(port: 9222)

        #expect(targets.count == 1)
        #expect(targets[0] == target)
    }

    @Test func testDiscoverTargetsEmptyArrayReturnsEmpty() async throws {
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data("[]".utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        let targets = try await discovery.discoverTargets(port: 9222)

        #expect(targets.isEmpty)
    }

    @Test func testDiscoverTargetsInvalidJSONThrowsDiscoveryFailed() async throws {
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data("not json".utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        await #expect(throws: CDPError.self) {
            _ = try await discovery.discoverTargets(port: 9222)
        }
    }

    @Test func testDiscoverTargetsNetworkErrorThrowsDiscoveryFailed() async throws {
        MockCDPURLProtocol.requestHandler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        do {
            _ = try await discovery.discoverTargets(port: 9222)
            Issue.record("Expected CDPError.discoveryFailed but no error thrown")
        } catch let error as CDPError {
            if case .discoveryFailed = error {
                // expected
            } else {
                Issue.record("Expected CDPError.discoveryFailed, got \(error)")
            }
        }
    }

    // MARK: findPageTarget

    @Test func testFindPageTargetReturnsFirstPageType() async throws {
        let json = """
        [
          {"id":"ext1","title":"Extension","url":"chrome-extension://abc","webSocketDebuggerUrl":"ws://localhost:9222/devtools/page/ext1","type":"background_page"},
          {"id":"page1","title":"Google","url":"https://google.com","webSocketDebuggerUrl":"ws://localhost:9222/devtools/page/page1","type":"page"},
          {"id":"page2","title":"GitHub","url":"https://github.com","webSocketDebuggerUrl":"ws://localhost:9222/devtools/page/page2","type":"page"}
        ]
        """
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data(json.utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        let target = try await discovery.findPageTarget(port: 9222)

        #expect(target.id == "page1")
        #expect(target.type == "page")
    }

    @Test func testFindPageTargetNoPageTargetsThrowsNoTargetsFound() async throws {
        let json = """
        [{"id":"ext1","title":"Extension","url":"chrome-extension://abc","webSocketDebuggerUrl":"ws://localhost:9222/devtools/page/ext1","type":"background_page"}]
        """
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data(json.utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        await #expect(throws: CDPError.noTargetsFound) {
            _ = try await discovery.findPageTarget(port: 9222)
        }
    }

    @Test func testFindPageTargetEmptyListThrowsNoTargetsFound() async throws {
        MockCDPURLProtocol.requestHandler = { _ in
            (CDPDiscoveryTests.jsonResponse(), Data("[]".utf8))
        }

        let discovery = CDPDiscoveryImpl(urlSession: CDPDiscoveryTests.makeSession())
        await #expect(throws: CDPError.noTargetsFound) {
            _ = try await discovery.findPageTarget(port: 9222)
        }
    }
}
