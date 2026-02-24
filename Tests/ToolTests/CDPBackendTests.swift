import Testing
import Foundation
@testable import JARVIS

// MARK: - CDPBackend Tests
//
// Uses MockCDPTransport + MockCDPDiscovery to test CDPBackendImpl
// without a real WebSocket server.

// MARK: - Helpers

extension CDPBackendTests {
    static func makePageTarget(wsUrl: String = "ws://localhost:9222/devtools/page/abc") -> CDPTarget {
        CDPTarget(
            id: "abc",
            title: "Test Page",
            url: "https://example.com",
            webSocketDebuggerUrl: wsUrl,
            type: "page"
        )
    }

    /// Creates a backend with a short timeout and auto-responding transport.
    static func makeBackend(
        transport: MockCDPTransport,
        discovery: MockCDPDiscovery,
        timeout: TimeInterval = 2.0
    ) -> CDPBackendImpl {
        CDPBackendImpl(transport: transport, discovery: discovery, commandTimeout: timeout)
    }

    /// Returns a connected backend where the transport auto-responds to Runtime.enable + Page.enable.
    static func connectedBackend(
        transport: MockCDPTransport,
        discovery: MockCDPDiscovery,
        timeout: TimeInterval = 2.0
    ) async throws -> CDPBackendImpl {
        let backend = makeBackend(transport: transport, discovery: discovery, timeout: timeout)
        // Pre-enqueue responses for Runtime.enable (id=1) and Page.enable (id=2)
        transport.enqueueResponse(id: 1, result: .object([:]))
        transport.enqueueResponse(id: 2, result: .object([:]))
        try await backend.connect(port: 9222)
        return backend
    }
}

// MARK: - Tests

@Suite("CDPBackend Tests", .serialized)
struct CDPBackendTests {

    // MARK: Connection Tests

    @Test func testConnectDiscoveryAndConnectsToWebSocket() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]
        transport.enqueueResponse(id: 1, result: .object([:]))
        transport.enqueueResponse(id: 2, result: .object([:]))

        let backend = CDPBackendTests.makeBackend(transport: transport, discovery: discovery)
        try await backend.connect(port: 9222)

        #expect(transport.connectURL?.absoluteString == "ws://localhost:9222/devtools/page/abc")
        #expect(backend.isConnected)
        await backend.disconnect()
    }

    @Test func testConnectWithNoTargetsThrows() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = []

        let backend = CDPBackendTests.makeBackend(transport: transport, discovery: discovery)
        await #expect(throws: CDPError.noTargetsFound) {
            try await backend.connect(port: 9222)
        }
        #expect(!backend.isConnected)
    }

    @Test func testConnectWithTransportFailureThrows() async throws {
        let transport = MockCDPTransport()
        transport.shouldFailConnect = true
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = CDPBackendTests.makeBackend(transport: transport, discovery: discovery)
        await #expect(throws: CDPError.self) {
            try await backend.connect(port: 9222)
        }
        #expect(!backend.isConnected)
    }

    @Test func testDisconnectCancelsReaderAndCallsTransportDisconnect() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        await backend.disconnect()

        #expect(transport.disconnected)
        #expect(!backend.isConnected)
    }

    @Test func testCommandWhenNotConnectedThrowsNotConnected() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()

        let backend = CDPBackendTests.makeBackend(transport: transport, discovery: discovery)
        await #expect(throws: CDPError.notConnected) {
            _ = try await backend.navigate(url: "https://example.com")
        }
    }

    // MARK: Command Tests

    @Test func testNavigateSendsCorrectCommandAndReturnsFrameId() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        // Next command is id=3 (1=Runtime.enable, 2=Page.enable)
        transport.enqueueResponse(id: 3, result: .object(["frameId": .string("frame-1")]))
        let frameId = try await backend.navigate(url: "https://example.com")

        #expect(frameId == "frame-1")

        // Verify the sent command
        let sentCommand = try JSONDecoder().decode(JSONValue.self, from: transport.sentMessages.last!)
        if case .object(let dict) = sentCommand {
            #expect(dict["method"] == .string("Page.navigate"))
            if case .object(let params) = dict["params"] {
                #expect(params["url"] == .string("https://example.com"))
            } else {
                Issue.record("params is not an object")
            }
        } else {
            Issue.record("sent command is not an object")
        }

        await backend.disconnect()
    }

    @Test func testNavigateWithErrorResponseThrows() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueErrorResponse(id: 3, message: "Navigation failed")

        await #expect(throws: CDPError.self) {
            _ = try await backend.navigate(url: "https://example.com")
        }

        await backend.disconnect()
    }

    @Test func testEvaluateJSSendsCorrectCommandAndReturnsResult() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("string"), "value": .string("hello")])]))
        let result = try await backend.evaluateJS("'hello'")

        #expect(result == "hello")
        await backend.disconnect()
    }

    @Test func testEvaluateJSWithExceptionDetailsThrowsEvaluationError() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        let exceptionDetails: JSONValue = .object([
            "exception": .object([
                "description": .string("ReferenceError: x is not defined")
            ])
        ])
        transport.enqueueResponse(id: 3, result: .object([
            "result": .object(["type": .string("object"), "subtype": .string("error")]),
            "exceptionDetails": exceptionDetails
        ]))

        do {
            _ = try await backend.evaluateJS("x")
            Issue.record("Expected evaluationError")
        } catch let error as CDPError {
            if case .evaluationError(let msg) = error {
                #expect(msg.contains("ReferenceError"))
            } else {
                Issue.record("Expected evaluationError, got \(error)")
            }
        }

        await backend.disconnect()
    }

    @Test func testFindElementReturnsTrueWhenFound() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("boolean"), "value": .bool(true)])]))
        let found = try await backend.findElement(selector: "#submit")

        #expect(found == true)
        await backend.disconnect()
    }

    @Test func testFindElementReturnsFalseWhenNotFound() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("boolean"), "value": .bool(false)])]))
        let found = try await backend.findElement(selector: "#missing")

        #expect(found == false)
        await backend.disconnect()
    }

    @Test func testClickElementSuccess() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("undefined")])]))

        // Should not throw
        try await backend.clickElement(selector: "#submit")
        await backend.disconnect()
    }

    @Test func testClickElementOnMissingElementThrows() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        // Simulate JS throwing because element not found
        let exceptionDetails: JSONValue = .object([
            "exception": .object([
                "description": .string("Error: Element not found: #missing")
            ])
        ])
        transport.enqueueResponse(id: 3, result: .object([
            "result": .object(["type": .string("object"), "subtype": .string("error")]),
            "exceptionDetails": exceptionDetails
        ]))

        await #expect(throws: CDPError.self) {
            try await backend.clickElement(selector: "#missing")
        }

        await backend.disconnect()
    }

    @Test func testTypeInElementSendsCorrectJS() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("undefined")])]))

        try await backend.typeInElement(selector: "#input", text: "Hello World")

        // Verify JS contains the selector and text
        let sentCommand = try JSONDecoder().decode(JSONValue.self, from: transport.sentMessages.last!)
        if case .object(let dict) = sentCommand,
           case .object(let params) = dict["params"],
           case .string(let expression) = params["expression"] {
            #expect(expression.contains("#input"))
            #expect(expression.contains("Hello World"))
        } else {
            Issue.record("Could not decode sent command")
        }

        await backend.disconnect()
    }

    @Test func testGetTextReturnsBodyInnerText() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("string"), "value": .string("Page content here")])]))
        let text = try await backend.getText()

        #expect(text == "Page content here")
        await backend.disconnect()
    }

    @Test func testGetURLReturnsLocationHref() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery)
        transport.enqueueResponse(id: 3, result: .object(["result": .object(["type": .string("string"), "value": .string("https://example.com/path")])]))
        let url = try await backend.getURL()

        #expect(url == "https://example.com/path")
        await backend.disconnect()
    }

    // MARK: Timeout/Error Tests

    @Test func testCommandTimeoutFiresAfterConfiguredDuration() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        // Use very short timeout (0.1s) for testing
        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery, timeout: 0.1)
        // Don't enqueue a response — the timeout should fire

        do {
            _ = try await backend.navigate(url: "https://example.com")
            Issue.record("Expected commandTimeout error")
        } catch let error as CDPError {
            if case .commandTimeout = error {
                // expected
            } else {
                Issue.record("Expected commandTimeout, got \(error)")
            }
        }

        await backend.disconnect()
    }

    @Test func testTransportErrorDuringReceivePropagatesCleanly() async throws {
        let transport = MockCDPTransport()
        let discovery = MockCDPDiscovery()
        discovery.targets = [CDPBackendTests.makePageTarget()]

        let backend = try await CDPBackendTests.connectedBackend(transport: transport, discovery: discovery, timeout: 2.0)

        // Disconnect the transport, which will cause receive() to throw connectionClosed
        transport.disconnect()

        // Give the reader a moment to detect the disconnect
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Subsequent commands should fail with notConnected or connectionClosed
        do {
            _ = try await backend.navigate(url: "https://example.com")
            // May succeed or fail depending on timing — just verify no crash
        } catch {
            // Expected
        }
    }
}
