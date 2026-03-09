import Testing
import Foundation
@testable import JARVIS

// MARK: - Helpers

private func makeInitializeResponse(id: Int, serverName: String = "TestServer") -> Data {
    let json = """
    {
      "jsonrpc": "2.0",
      "id": \(id),
      "result": {
        "protocolVersion": "\(MCPProtocolVersion)",
        "serverInfo": {"name": "\(serverName)", "version": "1.0"},
        "capabilities": {"tools": {}}
      }
    }
    """.data(using: .utf8)!
    return json
}

private func makeToolsListResponse(id: Int, tools: [[String: String]] = [], nextCursor: String? = nil) -> Data {
    let toolsJSON = tools.map { t -> String in
        """
        {"name":"\(t["name"]!)","description":"\(t["desc"] ?? "")","inputSchema":{"type":"object"}}
        """
    }.joined(separator: ",")
    let cursorPart = nextCursor.map { ",\"nextCursor\":\"\($0)\"" } ?? ""
    let json = """
    {"jsonrpc":"2.0","id":\(id),"result":{"tools":[\(toolsJSON)]\(cursorPart)}}
    """.data(using: .utf8)!
    return json
}

private func makeToolCallResponse(id: Int, text: String, isError: Bool = false) -> Data {
    let json = """
    {"jsonrpc":"2.0","id":\(id),"result":{"content":[{"type":"text","text":"\(text)"}],"isError":\(isError)}}
    """.data(using: .utf8)!
    return json
}

private func makeErrorResponse(id: Int, code: Int, message: String) -> Data {
    let json = """
    {"jsonrpc":"2.0","id":\(id),"error":{"code":\(code),"message":"\(message)"}}
    """.data(using: .utf8)!
    return json
}

// MARK: - MCPClientTests

@Suite("MCPClient Tests")
struct MCPClientTests {

    // MARK: - Handshake

    @Test func handshakeSuccessPopulatesServerInfo() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)

        transport.enqueueResponse(makeInitializeResponse(id: 1, serverName: "MyServer"))

        let info = try await client.initialize()
        #expect(info.name == "MyServer")
        #expect(client.isConnected == true)
        #expect(client.serverInfo?.name == "MyServer")
    }

    @Test func handshakeSendsCorrectFields() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, clientName: "JARVIS", clientVersion: "1.0.0", requestTimeout: 5)

        transport.enqueueResponse(makeInitializeResponse(id: 1))

        _ = try await client.initialize()

        // First message should be the initialize request
        guard let initRequest = transport.allSentRequests().first else {
            Issue.record("No request sent")
            return
        }
        #expect(initRequest.jsonrpc == "2.0")
        #expect(initRequest.method == "initialize")
        if case .object(let params) = initRequest.params,
           case .string(let ver) = params["protocolVersion"] {
            #expect(ver == MCPProtocolVersion)
        } else {
            Issue.record("Expected protocolVersion in params")
        }
    }

    @Test func handshakeSendsInitializedNotification() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)

        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // After initialize, a notifications/initialized notification must be sent
        let notifications = transport.allSentNotifications()
        let initialized = notifications.first { $0.method == "notifications/initialized" }
        #expect(initialized != nil)
    }

    @Test func handshakeVersionMismatchThrows() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)

        let badResponse = """
        {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"1999-01-01","serverInfo":{"name":"Old","version":"0.1"},"capabilities":{}}}
        """.data(using: .utf8)!
        transport.enqueueResponse(badResponse)

        await #expect(throws: MCPError.handshakeFailed("")) {
            _ = try await client.initialize()
        }
    }

    // MARK: - Tool Discovery

    @Test func listToolsReturnsTwoTools() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        transport.enqueueResponse(makeToolsListResponse(id: 2, tools: [
            ["name": "tool_a", "desc": "Alpha"],
            ["name": "tool_b", "desc": "Beta"]
        ]))
        let tools = try await client.listTools()
        #expect(tools.count == 2)
        #expect(tools[0].name == "tool_a")
        #expect(tools[1].name == "tool_b")
    }

    @Test func listToolsPaginates() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // First page: 1 tool + nextCursor
        transport.enqueueResponse(makeToolsListResponse(id: 2, tools: [["name": "tool_1"]], nextCursor: "cursor_abc"))
        // Second page: 1 tool, no cursor
        transport.enqueueResponse(makeToolsListResponse(id: 3, tools: [["name": "tool_2"]]))

        let tools = try await client.listTools()
        #expect(tools.count == 2)
        #expect(tools[0].name == "tool_1")
        #expect(tools[1].name == "tool_2")
    }

    // MARK: - Tool Execution

    @Test func callToolReturnsCorrectResult() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        transport.enqueueResponse(makeToolCallResponse(id: 2, text: "42"))
        let result = try await client.callTool(name: "calc", arguments: ["expr": .string("6*7")])
        #expect(result.isError == false)
        if case .text(let t) = result.content.first {
            #expect(t == "42")
        } else {
            Issue.record("Expected text content")
        }
    }

    @Test func callToolWithIsErrorReturnsResultNotThrows() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        transport.enqueueResponse(makeToolCallResponse(id: 2, text: "Error: not found", isError: true))
        let result = try await client.callTool(name: "find", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func callToolWithJSONRPCErrorThrows() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        transport.enqueueResponse(makeErrorResponse(id: 2, code: -32601, message: "Method not found"))
        await #expect(throws: MCPError.serverError(code: -32601, message: "Method not found")) {
            _ = try await client.callTool(name: "missing", arguments: [:])
        }
    }

    // MARK: - Timeout

    @Test func requestTimeoutThrowsTimeout() async throws {
        let transport = MockMCPTransport()
        // Very short timeout — do NOT enqueue a response
        let client = MCPClientImpl(transport: transport, requestTimeout: 0.1)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // No response enqueued — should timeout
        await #expect(throws: MCPError.timeout) {
            _ = try await client.callTool(name: "slow_tool", arguments: [:])
        }
    }

    // MARK: - Crash Detection

    @Test func serverCrashFailsPendingRequestsAndSetsDisconnected() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // Simulate crash before responding to callTool
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            transport.simulateCrash()
        }

        await #expect(throws: (any Error).self) {
            _ = try await client.callTool(name: "tool", arguments: [:])
        }
        #expect(client.isConnected == false)
    }

    // MARK: - Shutdown

    @Test func shutdownSetsIsConnectedFalse() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        #expect(client.isConnected == true)
        client.shutdown()
        #expect(client.isConnected == false)
    }

    // MARK: - Concurrent requests

    @Test func concurrentRequestsResolveByID() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // Send two concurrent requests; responses will arrive out of order (id 3 then 2)
        async let result1 = client.callTool(name: "tool_a", arguments: [:])
        async let result2 = client.callTool(name: "tool_b", arguments: [:])

        // Allow both requests to be sent before enqueuing responses
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Response for request 3 first, then request 2
        transport.enqueueResponse(makeToolCallResponse(id: 3, text: "result_b"))
        transport.enqueueResponse(makeToolCallResponse(id: 2, text: "result_a"))

        let (r1, r2) = try await (result1, result2)
        if case .text(let t) = r1.content.first { #expect(t == "result_a") }
        if case .text(let t) = r2.content.first { #expect(t == "result_b") }
    }

    // MARK: - Notification handling

    @Test func serverNotificationDoesNotConfuseClient() async throws {
        let transport = MockMCPTransport()
        let client = MCPClientImpl(transport: transport, requestTimeout: 5)
        transport.enqueueResponse(makeInitializeResponse(id: 1))
        _ = try await client.initialize()

        // Enqueue a server notification (no id) followed by a real response
        let notification = """
        {"jsonrpc":"2.0","method":"notifications/tools/list_changed"}
        """.data(using: .utf8)!
        transport.enqueueResponse(notification)
        transport.enqueueResponse(makeToolCallResponse(id: 2, text: "ok"))

        // Should still work correctly
        let result = try await client.callTool(name: "tool", arguments: [:])
        if case .text(let t) = result.content.first {
            #expect(t == "ok")
        } else {
            Issue.record("Expected text content")
        }
    }
}
