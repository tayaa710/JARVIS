import Foundation

// MARK: - MCPClientProtocol

protocol MCPClientProtocol: Sendable {
    func initialize() async throws -> MCPServerInfo
    func listTools() async throws -> [MCPTool]
    func callTool(name: String, arguments: [String: JSONValue]) async throws -> MCPToolCallResult
    func shutdown()
    var serverInfo: MCPServerInfo? { get }
    var isConnected: Bool { get }
}

// MARK: - MCPClientImpl

final class MCPClientImpl: MCPClientProtocol, @unchecked Sendable {

    // MARK: - Init

    init(
        transport: any MCPTransporting,
        clientName: String = "JARVIS",
        clientVersion: String = "1.0.0",
        requestTimeout: TimeInterval = 30
    ) {
        self.transport = transport
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.requestTimeout = requestTimeout
    }

    // MARK: - State

    private let transport: any MCPTransporting
    private let clientName: String
    private let clientVersion: String
    private let requestTimeout: TimeInterval

    private let lock = NSLock()
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var _serverInfo: MCPServerInfo?
    private var _isConnected: Bool = false
    private var receiveTask: Task<Void, Never>?

    // MARK: - MCPClientProtocol

    var serverInfo: MCPServerInfo? { lock.withLock { _serverInfo } }
    var isConnected: Bool { lock.withLock { _isConnected } }

    func initialize() async throws -> MCPServerInfo {
        try await transport.start()

        let params = JSONValue.object([
            "protocolVersion": .string(MCPProtocolVersion),
            "capabilities": .object([:]),
            "clientInfo": .object([
                "name": .string(clientName),
                "version": .string(clientVersion)
            ])
        ])

        startReceiveLoop()

        let response = try await sendRequest(method: "initialize", params: params)

        guard let result = response.result,
              case .object(let obj) = result,
              case .string(let version) = obj["protocolVersion"],
              case .object(let serverInfoObj) = obj["serverInfo"],
              case .string(let serverName) = serverInfoObj["name"],
              case .string(let serverVersion) = serverInfoObj["version"] else {
            throw MCPError.handshakeFailed("Invalid initialize response structure")
        }

        // Verify protocol version compatibility (major version must match)
        guard version == MCPProtocolVersion else {
            throw MCPError.handshakeFailed("Protocol version mismatch: server=\(version) client=\(MCPProtocolVersion)")
        }

        let info = MCPServerInfo(name: serverName, version: serverVersion)
        lock.withLock {
            _serverInfo = info
            _isConnected = true
        }

        // Send notifications/initialized
        let notification = JSONRPCNotification(method: "notifications/initialized", params: nil)
        if let data = try? JSONEncoder().encode(notification) {
            try? await transport.send(data)
        }

        Logger.mcp.info("MCP handshake complete with server: \(serverName) v\(serverVersion)")
        return info
    }

    func listTools() async throws -> [MCPTool] {
        var allTools: [MCPTool] = []
        var cursor: String? = nil

        repeat {
            let params: JSONValue? = cursor.map { .object(["cursor": .string($0)]) }
            let response = try await sendRequest(method: "tools/list", params: params)

            guard let result = response.result,
                  case .object(let obj) = result,
                  case .array(let toolsArray) = obj["tools"] else {
                break
            }

            let decoder = JSONDecoder()
            for item in toolsArray {
                guard let itemData = try? JSONEncoder().encode(item),
                      let tool = try? decoder.decode(MCPTool.self, from: itemData) else {
                    continue
                }
                allTools.append(tool)
            }

            if case .string(let next) = obj["nextCursor"] {
                cursor = next
            } else {
                cursor = nil
            }
        } while cursor != nil

        return allTools
    }

    func callTool(name: String, arguments: [String: JSONValue]) async throws -> MCPToolCallResult {
        let params = JSONValue.object([
            "name": .string(name),
            "arguments": .object(arguments)
        ])
        let response = try await sendRequest(method: "tools/call", params: params)

        if let error = response.error {
            throw MCPError.serverError(code: error.code, message: error.message)
        }

        guard let result = response.result else {
            throw MCPError.decodingFailed("No result in tools/call response")
        }

        guard let resultData = try? JSONEncoder().encode(result),
              let toolResult = try? JSONDecoder().decode(MCPToolCallResult.self, from: resultData) else {
            throw MCPError.decodingFailed("Failed to decode MCPToolCallResult")
        }

        return toolResult
    }

    func shutdown() {
        receiveTask?.cancel()
        transport.stop()
        let pending = lock.withLock { () -> [CheckedContinuation<JSONRPCResponse, Error>] in
            _isConnected = false
            let all = Array(pendingRequests.values)
            pendingRequests.removeAll()
            return all
        }
        for cont in pending {
            cont.resume(throwing: MCPError.transportClosed)
        }
        Logger.mcp.info("MCP client shutdown")
    }

    // MARK: - Internal

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.runReceiveLoop()
        }
    }

    private func runReceiveLoop() async {
        while !Task.isCancelled && isConnected {
            do {
                let data = try await transport.receive()
                handleReceivedData(data)
            } catch {
                Logger.mcp.error("MCP receive error: \(error)")
                lock.withLock { _isConnected = false }
                // Fail all pending requests
                let pending = lock.withLock { () -> [CheckedContinuation<JSONRPCResponse, Error>] in
                    let all = Array(pendingRequests.values)
                    pendingRequests.removeAll()
                    return all
                }
                for cont in pending {
                    cont.resume(throwing: error)
                }
                break
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        // Try to decode as a response first
        if let response = try? JSONDecoder().decode(JSONRPCResponse.self, from: data) {
            if let id = response.id {
                // It's a response to a pending request
                let cont = lock.withLock { pendingRequests.removeValue(forKey: id) }
                cont?.resume(returning: response)
            } else {
                // It's a server notification (no id) — log and ignore for now
                Logger.mcp.debug("MCP server notification received")
            }
        } else {
            Logger.mcp.warning("MCP: received undecodable data")
        }
    }

    private func sendRequest(method: String, params: JSONValue?) async throws -> JSONRPCResponse {
        let id = lock.withLock { () -> Int in
            let current = nextRequestId
            nextRequestId += 1
            return current
        }

        let request = JSONRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)

        return try await withThrowingTaskGroup(of: JSONRPCResponse.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { [weak self] continuation in
                    guard let self else {
                        continuation.resume(throwing: MCPError.transportClosed)
                        return
                    }
                    self.lock.withLock {
                        self.pendingRequests[id] = continuation
                    }
                }
            }

            group.addTask { [weak self] in
                guard let self else { throw MCPError.transportClosed }
                let nanos = UInt64(self.requestTimeout * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
                // Timeout fired — remove and fail the pending request
                let cont = self.lock.withLock { self.pendingRequests.removeValue(forKey: id) }
                cont?.resume(throwing: MCPError.timeout)
                throw MCPError.timeout
            }

            // Send the request after registering the continuation
            do {
                try await transport.send(data)
            } catch {
                // Remove pending and fail
                let cont = lock.withLock { pendingRequests.removeValue(forKey: id) }
                cont?.resume(throwing: error)
                group.cancelAll()
                throw error
            }

            // Return whichever task finishes first
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
