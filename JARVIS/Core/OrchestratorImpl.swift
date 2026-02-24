import Foundation

final class OrchestratorImpl: Orchestrator, @unchecked Sendable {

    // MARK: - Dependencies

    private let modelProvider: any ModelProvider
    private let toolRegistry: any ToolRegistry
    private let policyEngine: any PolicyEngine
    private let systemPrompt: String?
    let maxRounds: Int
    let timeout: TimeInterval
    private let confirmationHandler: ConfirmationHandler?
    private let sessionLogger: (any SessionLogging)?

    // MARK: - State (NSLock-protected)

    private let lock = NSLock()
    private var _conversationHistory: [Message] = []
    private var _contextLock: ContextLock?
    private var _currentTask: Task<OrchestratorResult, Error>?
    private var _abortRequested = false

    // MARK: - Init

    init(
        modelProvider: any ModelProvider,
        toolRegistry: any ToolRegistry,
        policyEngine: any PolicyEngine,
        systemPrompt: String? = nil,
        maxRounds: Int = 25,
        timeout: TimeInterval = 300,
        confirmationHandler: ConfirmationHandler? = nil,
        sessionLogger: (any SessionLogging)? = nil
    ) {
        self.modelProvider = modelProvider
        self.toolRegistry = toolRegistry
        self.policyEngine = policyEngine
        self.systemPrompt = systemPrompt
        self.maxRounds = maxRounds
        self.timeout = timeout
        self.confirmationHandler = confirmationHandler
        self.sessionLogger = sessionLogger
    }

    // MARK: - Orchestrator

    var contextLock: ContextLock? {
        lock.withLock { _contextLock }
    }

    func setContextLock(_ lock: ContextLock) {
        self.lock.withLock { _contextLock = lock }
    }

    func clearContextLock() {
        lock.withLock { _contextLock = nil }
    }

    var conversationHistory: [Message] {
        lock.withLock { _conversationHistory }
    }

    func reset() {
        lock.withLock { _conversationHistory = [] }
    }

    func abort() {
        let task = lock.withLock {
            _abortRequested = true
            return _currentTask
        }
        task?.cancel()
        modelProvider.abort()
        Logger.orchestrator.info("Orchestrator abort requested")
    }

    func process(userMessage: String) async throws -> OrchestratorResult {
        lock.withLock { _abortRequested = false }
        lock.withLock { _conversationHistory.append(Message(role: .user, text: userMessage)) }
        sessionLogger?.logUserMessage(userMessage)

        let startTime = Date()

        // Create a dedicated work task so abort() can cancel it independently
        let workTask = Task<OrchestratorResult, Error> { [self] in
            try await self.runLoop(startTime: startTime)
        }

        lock.withLock { _currentTask = workTask }
        defer { lock.withLock { _currentTask = nil } }

        return try await withThrowingTaskGroup(of: OrchestratorResult.self) { group in
            // Child task 1: wraps the work task and maps CancellationError → .cancelled
            group.addTask {
                do {
                    return try await workTask.value
                } catch is CancellationError {
                    let wasAborted = self.lock.withLock { self._abortRequested }
                    throw wasAborted ? OrchestratorError.cancelled : CancellationError()
                }
            }

            // Child task 2: fires the timeout
            let timeoutSeconds = self.timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw OrchestratorError.timeout
            }

            defer {
                group.cancelAll()
                workTask.cancel()
            }
            guard let result = try await group.next() else {
                throw OrchestratorError.noResponse
            }
            return result
        }
    }

    func processWithStreaming(
        userMessage: String,
        onEvent: @escaping OrchestratorEventHandler
    ) async throws -> OrchestratorResult {
        lock.withLock { _abortRequested = false }
        lock.withLock { _conversationHistory.append(Message(role: .user, text: userMessage)) }
        sessionLogger?.logUserMessage(userMessage)

        let startTime = Date()

        let workTask = Task<OrchestratorResult, Error> { [self] in
            try await self.runStreamingLoop(startTime: startTime, onEvent: onEvent)
        }

        lock.withLock { _currentTask = workTask }
        defer { lock.withLock { _currentTask = nil } }

        return try await withThrowingTaskGroup(of: OrchestratorResult.self) { group in
            group.addTask {
                do {
                    return try await workTask.value
                } catch is CancellationError {
                    let wasAborted = self.lock.withLock { self._abortRequested }
                    throw wasAborted ? OrchestratorError.cancelled : CancellationError()
                }
            }

            let timeoutSeconds = self.timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw OrchestratorError.timeout
            }

            defer {
                group.cancelAll()
                workTask.cancel()
            }
            guard let result = try await group.next() else {
                throw OrchestratorError.noResponse
            }
            return result
        }
    }

    // MARK: - Private: Main Loop

    private func runLoop(startTime: Date) async throws -> OrchestratorResult {
        var roundCount = 0
        var toolsUsed: [String] = []
        var errorsEncountered = 0
        var inputTokens = 0
        var outputTokens = 0

        Logger.orchestrator.info("Starting orchestrator loop (maxRounds=\(self.maxRounds))")

        while roundCount < maxRounds {
            try Task.checkCancellation()

            let history = lock.withLock { _conversationHistory }
            let tools = toolRegistry.allDefinitions()

            Logger.orchestrator.info("Round \(roundCount + 1): \(history.count) messages, \(tools.count) tools")
            sessionLogger?.logThinkingRound(roundCount + 1, messageCount: history.count, toolCount: tools.count)

            let response = try await modelProvider.send(
                messages: history,
                tools: tools,
                system: systemPrompt
            )

            // Append assistant response to history
            lock.withLock {
                _conversationHistory.append(Message(role: .assistant, content: response.content))
            }

            inputTokens += response.usage.inputTokens
            outputTokens += response.usage.outputTokens
            roundCount += 1

            // Extract tool_use blocks
            let toolUseBlocks = response.content.compactMap { block -> ToolUse? in
                if case .toolUse(let tu) = block { return tu }
                return nil
            }

            // If no tool use requested, extract text and return
            if toolUseBlocks.isEmpty || response.stopReason != .toolUse {
                let text = response.content.compactMap { block -> String? in
                    if case .text(let t) = block { return t }
                    return nil
                }.joined()

                let elapsed = Date().timeIntervalSince(startTime)
                Logger.orchestrator.info(
                    "Loop done: \(roundCount) round(s), \(toolsUsed.count) tool(s), \(errorsEncountered) error(s), \(String(format: "%.2f", elapsed))s"
                )
                let result = OrchestratorResult(
                    text: text,
                    metrics: TurnMetrics(
                        roundCount: roundCount,
                        elapsedTime: elapsed,
                        toolsUsed: toolsUsed,
                        errorsEncountered: errorsEncountered,
                        inputTokens: inputTokens,
                        outputTokens: outputTokens
                    )
                )
                if !text.isEmpty { sessionLogger?.logAssistantText(text) }
                sessionLogger?.logMetrics(result.metrics)
                return result
            }

            // Process each tool use block
            var toolResultBlocks: [ContentBlock] = []
            for toolUse in toolUseBlocks {
                let toolStart = Date()
                let executor = toolRegistry.executor(for: toolUse.name)
                let riskLevel = executor?.riskLevel ?? .dangerous
                let decision = policyEngine.evaluate(call: toolUse, riskLevel: riskLevel)

                Logger.orchestrator.info(
                    "Tool '\(toolUse.name)' risk=\(String(describing: riskLevel)) decision=\(String(describing: decision))"
                )
                sessionLogger?.logToolCall(name: toolUse.name, inputJSON: inputJSON(toolUse.input), risk: riskLevel, decision: decision)

                switch decision {
                case .deny:
                    Logger.orchestrator.warning("Tool '\(toolUse.name)' denied by policy")
                    sessionLogger?.logToolDenied(name: toolUse.name)
                    toolResultBlocks.append(.toolResult(ToolResult(
                        toolUseId: toolUse.id,
                        content: "Tool call denied by safety policy.",
                        isError: true
                    )))
                    errorsEncountered += 1

                case .requireConfirmation:
                    let approved: Bool
                    if let handler = confirmationHandler {
                        approved = await handler(toolUse)
                    } else {
                        approved = false // Safe default: auto-deny
                    }

                    if approved {
                        let result = await executeToolSafely(toolUse, start: toolStart)
                        sessionLogger?.logToolResult(name: toolUse.name, isError: result.isError, elapsed: Date().timeIntervalSince(toolStart), output: result.content)
                        toolResultBlocks.append(.toolResult(result))
                        if result.isError { errorsEncountered += 1 } else { toolsUsed.append(toolUse.name) }
                    } else {
                        Logger.orchestrator.info("Tool '\(toolUse.name)' rejected by user")
                        sessionLogger?.logToolRejected(name: toolUse.name)
                        toolResultBlocks.append(.toolResult(ToolResult(
                            toolUseId: toolUse.id,
                            content: "Tool call rejected by user.",
                            isError: true
                        )))
                        errorsEncountered += 1
                    }

                case .allow:
                    let result = await executeToolSafely(toolUse, start: toolStart)
                    sessionLogger?.logToolResult(name: toolUse.name, isError: result.isError, elapsed: Date().timeIntervalSince(toolStart), output: result.content)
                    toolResultBlocks.append(.toolResult(result))
                    if result.isError { errorsEncountered += 1 } else { toolsUsed.append(toolUse.name) }
                }
            }

            // Append tool results as a user message
            lock.withLock {
                _conversationHistory.append(Message(role: .user, content: toolResultBlocks))
            }
        }

        Logger.orchestrator.warning("Max rounds exceeded (\(maxRounds))")
        throw OrchestratorError.maxRoundsExceeded
    }

    // MARK: - Private: Streaming Loop

    private func runStreamingLoop(
        startTime: Date,
        onEvent: @escaping OrchestratorEventHandler
    ) async throws -> OrchestratorResult {
        var roundCount = 0
        var toolsUsed: [String] = []
        var errorsEncountered = 0
        var totalInputTokens = 0
        var totalOutputTokens = 0

        Logger.orchestrator.info("Starting streaming loop (maxRounds=\(self.maxRounds))")

        while roundCount < maxRounds {
            try Task.checkCancellation()

            let history = lock.withLock { _conversationHistory }
            let tools = toolRegistry.allDefinitions()

            Logger.orchestrator.info("Streaming round \(roundCount + 1): \(history.count) messages, \(tools.count) tools")
            sessionLogger?.logThinkingRound(roundCount + 1, messageCount: history.count, toolCount: tools.count)

            onEvent(.thinkingStarted)

            let stream = modelProvider.sendStreaming(messages: history, tools: tools, system: systemPrompt)

            var textAccumulator = ""
            var pendingToolUses: [Int: (id: String, name: String)] = [:]
            var pendingInputJSON: [Int: String] = [:]
            var completedToolUses: [ToolUse] = []
            var stopReason: StopReason?
            var roundOutputTokens = 0

            for try await event in stream {
                try Task.checkCancellation()
                switch event {
                case .messageStart:
                    break
                case .textDelta(let text):
                    textAccumulator += text
                    onEvent(.textDelta(text))
                case .toolUseStart(let index, let toolUse):
                    pendingToolUses[index] = (id: toolUse.id, name: toolUse.name)
                    pendingInputJSON[index] = ""
                case .inputJSONDelta(let index, let delta):
                    pendingInputJSON[index, default: ""] += delta
                case .contentBlockStop(let index):
                    if let pending = pendingToolUses[index] {
                        let jsonStr = pendingInputJSON[index] ?? ""
                        let input: [String: JSONValue]
                        if jsonStr.isEmpty {
                            input = [:]
                        } else if let data = jsonStr.data(using: .utf8),
                                  let parsed = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
                            input = parsed
                        } else {
                            input = [:]
                        }
                        completedToolUses.append(ToolUse(id: pending.id, name: pending.name, input: input))
                        pendingToolUses.removeValue(forKey: index)
                        pendingInputJSON.removeValue(forKey: index)
                    }
                case .messageDelta(let reason, let usage):
                    stopReason = reason
                    roundOutputTokens = usage.outputTokens
                case .messageStop:
                    break
                case .ping:
                    break
                }
            }

            // Build content blocks from accumulated data
            var contentBlocks: [ContentBlock] = []
            if !textAccumulator.isEmpty {
                contentBlocks.append(.text(textAccumulator))
            }
            for toolUse in completedToolUses {
                contentBlocks.append(.toolUse(toolUse))
            }

            // Append assistant message to history
            lock.withLock {
                _conversationHistory.append(Message(role: .assistant, content: contentBlocks))
            }

            totalOutputTokens += roundOutputTokens
            roundCount += 1

            // If no tool use requested (or stop reason is end_turn), return
            if completedToolUses.isEmpty || stopReason != .toolUse {
                let elapsed = Date().timeIntervalSince(startTime)
                Logger.orchestrator.info(
                    "Streaming loop done: \(roundCount) round(s), \(toolsUsed.count) tool(s), " +
                    "\(errorsEncountered) error(s), \(String(format: "%.2f", elapsed))s"
                )
                let result = OrchestratorResult(
                    text: textAccumulator,
                    metrics: TurnMetrics(
                        roundCount: roundCount,
                        elapsedTime: elapsed,
                        toolsUsed: toolsUsed,
                        errorsEncountered: errorsEncountered,
                        inputTokens: totalInputTokens,
                        outputTokens: totalOutputTokens
                    )
                )
                if !textAccumulator.isEmpty { sessionLogger?.logAssistantText(textAccumulator) }
                sessionLogger?.logMetrics(result.metrics)
                onEvent(.completed(result))
                return result
            }

            // Process tool calls
            var toolResultBlocks: [ContentBlock] = []
            for toolUse in completedToolUses {
                let toolStart = Date()
                let executor = toolRegistry.executor(for: toolUse.name)
                let riskLevel = executor?.riskLevel ?? .dangerous
                let decision = policyEngine.evaluate(call: toolUse, riskLevel: riskLevel)

                Logger.orchestrator.info(
                    "Tool '\(toolUse.name)' risk=\(String(describing: riskLevel)) decision=\(String(describing: decision))"
                )
                sessionLogger?.logToolCall(name: toolUse.name, inputJSON: inputJSON(toolUse.input), risk: riskLevel, decision: decision)

                onEvent(.toolStarted(name: toolUse.name))

                switch decision {
                case .deny:
                    Logger.orchestrator.warning("Tool '\(toolUse.name)' denied by policy")
                    sessionLogger?.logToolDenied(name: toolUse.name)
                    let denied = ToolResult(toolUseId: toolUse.id, content: "Tool call denied by safety policy.", isError: true)
                    onEvent(.toolCompleted(name: toolUse.name, result: denied.content, isError: true))
                    toolResultBlocks.append(.toolResult(denied))
                    errorsEncountered += 1

                case .requireConfirmation:
                    let approved: Bool
                    if let handler = confirmationHandler {
                        approved = await handler(toolUse)
                    } else {
                        approved = false
                    }
                    if approved {
                        let result = await executeToolSafely(toolUse, start: toolStart)
                        sessionLogger?.logToolResult(name: toolUse.name, isError: result.isError, elapsed: Date().timeIntervalSince(toolStart), output: result.content)
                        onEvent(.toolCompleted(name: toolUse.name, result: result.content, isError: result.isError))
                        toolResultBlocks.append(.toolResult(result))
                        if result.isError { errorsEncountered += 1 } else { toolsUsed.append(toolUse.name) }
                    } else {
                        Logger.orchestrator.info("Tool '\(toolUse.name)' rejected by user")
                        sessionLogger?.logToolRejected(name: toolUse.name)
                        let rejected = ToolResult(toolUseId: toolUse.id, content: "Tool call rejected by user.", isError: true)
                        onEvent(.toolCompleted(name: toolUse.name, result: rejected.content, isError: true))
                        toolResultBlocks.append(.toolResult(rejected))
                        errorsEncountered += 1
                    }

                case .allow:
                    let result = await executeToolSafely(toolUse, start: toolStart)
                    sessionLogger?.logToolResult(name: toolUse.name, isError: result.isError, elapsed: Date().timeIntervalSince(toolStart), output: result.content)
                    onEvent(.toolCompleted(name: toolUse.name, result: result.content, isError: result.isError))
                    toolResultBlocks.append(.toolResult(result))
                    if result.isError { errorsEncountered += 1 } else { toolsUsed.append(toolUse.name) }
                }
            }

            // Append tool results as user message
            lock.withLock {
                _conversationHistory.append(Message(role: .user, content: toolResultBlocks))
            }
        }

        Logger.orchestrator.warning("Streaming max rounds exceeded (\(maxRounds))")
        throw OrchestratorError.maxRoundsExceeded
    }

    // MARK: - Private: Tool Execution

    private func executeToolSafely(_ toolUse: ToolUse, start: Date) async -> ToolResult {
        Logger.orchestrator.info("Executing '\(toolUse.name)' id=\(toolUse.id)")
        do {
            let result = try await toolRegistry.dispatch(call: toolUse)
            let elapsed = Date().timeIntervalSince(start)
            Logger.orchestrator.info(
                "Tool '\(toolUse.name)' done in \(String(format: "%.3f", elapsed))s isError=\(result.isError)"
            )
            return result
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            Logger.orchestrator.error(
                "Tool '\(toolUse.name)' error in \(String(format: "%.3f", elapsed))s: \(error)"
            )
            return ToolResult(
                toolUseId: toolUse.id,
                content: "Tool failed: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private func inputJSON(_ input: [String: JSONValue]) -> String {
        guard !input.isEmpty,
              let data = try? JSONEncoder().encode(input),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
