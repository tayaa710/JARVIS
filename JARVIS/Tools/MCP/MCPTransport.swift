import Foundation

// MARK: - MCPTransporting Protocol

protocol MCPTransporting: Sendable {
    func start() async throws
    func send(_ message: Data) async throws
    func receive() async throws -> Data
    func stop()
    var isRunning: Bool { get }
}

// MARK: - StdioMCPTransport

/// Launches an external MCP server process and communicates via stdin/stdout
/// using newline-delimited JSON (per the MCP stdio transport spec).
final class StdioMCPTransport: MCPTransporting, @unchecked Sendable {

    // MARK: - Init

    init(
        command: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
    }

    // MARK: - State

    private let command: String
    private let arguments: [String]
    private let environment: [String: String]?

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    private let lock = NSLock()
    private var _isRunning = false

    private var lineStream: AsyncStream<Result<Data, Error>>?
    private var lineStreamContinuation: AsyncStream<Result<Data, Error>>.Continuation?
    private var lineIterator: AsyncStream<Result<Data, Error>>.AsyncIterator?

    // MARK: - MCPTransporting

    var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    func start() async throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = arguments

        if let env = environment {
            var combined = ProcessInfo.processInfo.environment
            for (k, v) in env { combined[k] = v }
            proc.environment = combined
        }

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.standardError

        var cap: AsyncStream<Result<Data, Error>>.Continuation?
        let stream = AsyncStream<Result<Data, Error>> { continuation in
            cap = continuation
        }
        let continuation = cap!
        lineStream = stream
        lineStreamContinuation = continuation
        lineIterator = stream.makeAsyncIterator()

        // Buffer accumulator — runs on readabilityHandler background thread
        let bufferBox = BufferBox()
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            if chunk.isEmpty {
                // EOF — process closed stdout
                continuation.finish()
                return
            }
            bufferBox.append(chunk)
            // Emit complete lines
            while let line = bufferBox.consumeLine() {
                if !line.isEmpty {
                    continuation.yield(.success(line))
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self else { return }
            lock.withLock { self._isRunning = false }
            continuation.yield(.failure(MCPError.serverCrashed))
            continuation.finish()
            Logger.mcp.info("MCP server process terminated")
        }

        try proc.run()
        Logger.mcp.info("MCP server started: \(command)")

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        lock.withLock { _isRunning = true }
    }

    func send(_ message: Data) async throws {
        guard isRunning, let stdinPipe else {
            throw MCPError.transportClosed
        }
        var framed = message
        framed.append(0x0A) // newline
        try stdinPipe.fileHandleForWriting.write(contentsOf: framed)
    }

    func receive() async throws -> Data {
        guard var iterator = lineIterator else {
            throw MCPError.transportClosed
        }
        guard let result = await iterator.next() else {
            throw MCPError.transportClosed
        }
        lineIterator = iterator
        switch result {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }

    func stop() {
        lock.withLock { _isRunning = false }
        lineStreamContinuation?.finish()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdinPipe?.fileHandleForWriting.closeFile()
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        Logger.mcp.info("MCP transport stopped")
    }
}

// MARK: - BufferBox (thread-safe line accumulator)

private final class BufferBox: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    func append(_ data: Data) {
        lock.withLock { buffer.append(data) }
    }

    /// Returns the next complete line (without the newline byte), or nil if none available.
    func consumeLine() -> Data? {
        lock.withLock {
            guard let idx = buffer.firstIndex(of: 0x0A) else { return nil }
            let line = buffer[buffer.startIndex..<idx]
            buffer = buffer[(idx + 1)...]
            return Data(line)
        }
    }
}
