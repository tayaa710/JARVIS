import Foundation

// MARK: - CDPBackendImpl

/// Chrome DevTools Protocol backend implementation.
///
/// Manages a WebSocket connection to a Chromium-family browser, correlates
/// request-response messages by id, and exposes high-level browser control commands.
public final class CDPBackendImpl: CDPBackendProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let transport: any CDPTransport
    private let discovery: any CDPDiscovering
    private let commandTimeout: TimeInterval

    // MARK: - Mutable State (NSLock-protected)

    private let lock = NSLock()
    private var pendingRequests: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var nextId: Int = 1
    private var readerTask: Task<Void, Never>?
    private var _isConnected: Bool = false

    // MARK: - CDPBackendProtocol

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    // MARK: - Init

    public init(
        transport: any CDPTransport,
        discovery: any CDPDiscovering,
        commandTimeout: TimeInterval = 10.0
    ) {
        self.transport = transport
        self.discovery = discovery
        self.commandTimeout = commandTimeout
    }

    // MARK: - Connect / Disconnect

    public func connect(port: Int = 9222) async throws {
        let target = try await discovery.findPageTarget(port: port)
        guard let url = URL(string: target.webSocketDebuggerUrl) else {
            throw CDPError.connectionFailed("Invalid WebSocket URL: \(target.webSocketDebuggerUrl)")
        }
        do {
            try await transport.connect(to: url)
        } catch let error as CDPError {
            throw error
        } catch {
            throw CDPError.connectionFailed(error.localizedDescription)
        }

        lock.lock()
        _isConnected = true
        lock.unlock()

        // Start background reader
        let readerTask = Task { [weak self] in
            guard let self else { return }
            await self.runReader()
        }
        lock.lock()
        self.readerTask = readerTask
        lock.unlock()

        // Enable required CDP domains
        _ = try? await sendCommand(method: "Runtime.enable", params: [:])
        _ = try? await sendCommand(method: "Page.enable", params: [:])
        Logger.cdp.info("Connected to CDP target: \(target.title) (\(target.url))")
    }

    public func disconnect() async {
        lock.lock()
        let pending = pendingRequests
        pendingRequests = [:]
        _isConnected = false
        readerTask?.cancel()
        readerTask = nil
        lock.unlock()

        // Resume all pending continuations with connectionClosed
        for (_, continuation) in pending {
            continuation.resume(throwing: CDPError.connectionClosed)
        }

        transport.disconnect()
        Logger.cdp.info("Disconnected from CDP")
    }

    // MARK: - Background Reader

    private func runReader() async {
        while !Task.isCancelled {
            do {
                let data = try await transport.receive()
                handleMessage(data)
            } catch {
                if Task.isCancelled { break }
                Logger.cdp.error("CDP reader error: \(error)")
                // Resume all pending continuations with connectionClosed
                lock.lock()
                let pending = pendingRequests
                pendingRequests = [:]
                _isConnected = false
                lock.unlock()
                for (_, continuation) in pending {
                    continuation.resume(throwing: CDPError.connectionClosed)
                }
                break
            }
        }
    }

    private func handleMessage(_ data: Data) {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(let dict) = value else { return }

        // Only handle responses (messages with an "id" field)
        guard case .number(let idNum) = dict["id"] else { return }
        let id = Int(idNum)

        lock.lock()
        let continuation = pendingRequests.removeValue(forKey: id)
        lock.unlock()

        guard let continuation else { return }

        if let errorValue = dict["error"] {
            continuation.resume(throwing: CDPError.invalidResponse("CDP error: \(errorValue)"))
        } else {
            let result = dict["result"] ?? .object([:])
            continuation.resume(returning: result)
        }
    }

    // MARK: - Command Sending

    private func sendCommand(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        guard isConnected else {
            throw CDPError.notConnected
        }

        let id: Int = lock.withLock {
            let current = nextId
            nextId += 1
            return current
        }

        let command: [String: JSONValue] = [
            "id": .number(Double(id)),
            "method": .string(method),
            "params": .object(params)
        ]
        let data = try JSONEncoder().encode(JSONValue.object(command))
        try await transport.send(data)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingRequests[id] = continuation
            lock.unlock()

            // Timeout task
            let timeout = commandTimeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                self.lock.lock()
                let pending = self.pendingRequests.removeValue(forKey: id)
                self.lock.unlock()
                pending?.resume(throwing: CDPError.commandTimeout("\(method) timed out after \(timeout)s"))
            }
        }
    }

    // MARK: - JS Escaping

    private func escapeJSString(_ string: String) -> String {
        var result = ""
        for char in string {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "'":  result += "\\'"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:   result.append(char)
            }
        }
        return result
    }

    // MARK: - High-Level Commands

    public func navigate(url: String) async throws -> String {
        let result = try await sendCommand(method: "Page.navigate", params: ["url": .string(url)])
        guard case .object(let dict) = result,
              case .string(let frameId) = dict["frameId"] else {
            throw CDPError.invalidResponse("Page.navigate missing frameId in response")
        }
        return frameId
    }

    public func evaluateJS(_ expression: String) async throws -> String {
        let params: [String: JSONValue] = [
            "expression": .string(expression),
            "returnByValue": .bool(true)
        ]
        let result = try await sendCommand(method: "Runtime.evaluate", params: params)
        guard case .object(let dict) = result else {
            throw CDPError.invalidResponse("Runtime.evaluate returned non-object")
        }
        if let exceptionDetails = dict["exceptionDetails"] {
            let message: String
            if case .object(let exc) = exceptionDetails,
               case .object(let excValue) = exc["exception"],
               case .string(let desc) = excValue["description"] {
                message = desc
            } else {
                message = "\(exceptionDetails)"
            }
            throw CDPError.evaluationError(message)
        }
        guard case .object(let resultObj) = dict["result"] else {
            return ""
        }
        switch resultObj["value"] {
        case .string(let value): return value
        case .bool(let value):   return value ? "true" : "false"
        case .number(let value): return String(value)
        case .null, .none:       return "null"
        default:                 return "\(resultObj["value"] as Any)"
        }
    }

    public func findElement(selector: String) async throws -> Bool {
        let escaped = escapeJSString(selector)
        let js = "document.querySelector('\(escaped)') !== null"
        let result = try await evaluateJS(js)
        return result == "true"
    }

    public func clickElement(selector: String) async throws {
        let escaped = escapeJSString(selector)
        let js = """
        (function() {
          var el = document.querySelector('\(escaped)');
          if (!el) throw new Error('Element not found: \(escaped)');
          el.click();
        })()
        """
        _ = try await evaluateJS(js)
    }

    public func typeInElement(selector: String, text: String) async throws {
        let escapedSelector = escapeJSString(selector)
        let escapedText = escapeJSString(text)
        let js = """
        (function() {
          var el = document.querySelector('\(escapedSelector)');
          if (!el) throw new Error('Element not found: \(escapedSelector)');
          el.focus();
          el.value = '\(escapedText)';
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        })()
        """
        _ = try await evaluateJS(js)
    }

    public func getText() async throws -> String {
        return try await evaluateJS("document.body.innerText")
    }

    public func getURL() async throws -> String {
        return try await evaluateJS("window.location.href")
    }
}
