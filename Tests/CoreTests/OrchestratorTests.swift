import Testing
import Foundation
@testable import JARVIS

// Helper to build a simple end_turn Response
private func textResponse(_ text: String, id: String = "resp-1") -> Response {
    Response(
        id: id,
        model: "claude-sonnet-4-6",
        content: [.text(text)],
        stopReason: .endTurn,
        usage: Usage(inputTokens: 10, outputTokens: 5)
    )
}

// Helper to build a tool_use Response
private func toolUseResponse(toolId: String, toolName: String, input: [String: JSONValue] = [:], id: String = "resp-2") -> Response {
    Response(
        id: id,
        model: "claude-sonnet-4-6",
        content: [.toolUse(ToolUse(id: toolId, name: toolName, input: input))],
        stopReason: .toolUse,
        usage: Usage(inputTokens: 10, outputTokens: 5)
    )
}

// Helper to build an Orchestrator with defaults
private func makeOrchestrator(
    model: MockModelProvider,
    registry: ToolRegistryImpl = ToolRegistryImpl(),
    policy: any PolicyEngine = MockPolicyEngine(),
    maxRounds: Int = 25,
    timeout: TimeInterval = 30,
    confirmationHandler: ConfirmationHandler? = nil
) -> OrchestratorImpl {
    OrchestratorImpl(
        modelProvider: model,
        toolRegistry: registry,
        policyEngine: policy,
        maxRounds: maxRounds,
        timeout: timeout,
        confirmationHandler: confirmationHandler
    )
}

@Suite("OrchestratorImpl Tests")
struct OrchestratorTests {

    // MARK: - 1. testSimpleTextResponse

    @Test func testSimpleTextResponse() async throws {
        let model = MockModelProvider()
        model.enqueue(response: textResponse("Hello, world!"))

        let orch = makeOrchestrator(model: model)
        let result = try await orch.process(userMessage: "hello")

        #expect(result.text == "Hello, world!")
        #expect(result.metrics.roundCount == 1)
        #expect(result.metrics.toolsUsed.isEmpty)
        #expect(result.metrics.errorsEncountered == 0)
    }

    // MARK: - 2. testSingleToolRound

    @Test func testSingleToolRound() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "system_info", result: "macOS 14.0"))
        // Round 1: tool_use for system_info
        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "system_info"))
        // Round 2: final text
        model.enqueue(response: textResponse("Your OS is macOS 14.0"))

        let orch = makeOrchestrator(model: model, registry: registry)
        let result = try await orch.process(userMessage: "What OS am I on?")

        #expect(result.text == "Your OS is macOS 14.0")
        #expect(result.metrics.roundCount == 2)
        #expect(result.metrics.toolsUsed == ["system_info"])
    }

    // MARK: - 3. testMultiRoundToolUse

    @Test func testMultiRoundToolUse() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "tool_a"))
        try registry.register(makeStubTool(name: "tool_b"))

        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "tool_a", id: "r1"))
        model.enqueue(response: toolUseResponse(toolId: "tu-2", toolName: "tool_b", id: "r2"))
        model.enqueue(response: toolUseResponse(toolId: "tu-3", toolName: "tool_a", id: "r3"))
        model.enqueue(response: textResponse("Done", id: "r4"))

        let orch = makeOrchestrator(model: model, registry: registry)
        let result = try await orch.process(userMessage: "Do something complex")

        #expect(result.metrics.roundCount == 4)
        #expect(result.metrics.toolsUsed == ["tool_a", "tool_b", "tool_a"])
    }

    // MARK: - 4. testMultipleToolsInSingleResponse

    @Test func testMultipleToolsInSingleResponse() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "tool_a"))
        try registry.register(makeStubTool(name: "tool_b"))

        // Single response with two tool_use blocks
        let twoToolsResponse = Response(
            id: "r1",
            model: "claude-sonnet-4-6",
            content: [
                .toolUse(ToolUse(id: "tu-1", name: "tool_a", input: [:])),
                .toolUse(ToolUse(id: "tu-2", name: "tool_b", input: [:]))
            ],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 10, outputTokens: 5)
        )
        model.enqueue(response: twoToolsResponse)
        model.enqueue(response: textResponse("Both done"))

        let orch = makeOrchestrator(model: model, registry: registry)
        let result = try await orch.process(userMessage: "Do two things")

        // Both tools executed in one round (round 1), then final text (round 2)
        #expect(result.metrics.roundCount == 2)
        #expect(result.metrics.toolsUsed.contains("tool_a"))
        #expect(result.metrics.toolsUsed.contains("tool_b"))
        #expect(result.metrics.toolsUsed.count == 2)
    }

    // MARK: - 5. testMaxRoundsEnforcement

    @Test func testMaxRoundsEnforcement() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "loop_tool"))

        // Enqueue more tool_use responses than maxRounds
        for i in 0..<5 {
            model.enqueue(response: toolUseResponse(toolId: "tu-\(i)", toolName: "loop_tool", id: "r\(i)"))
        }

        let orch = makeOrchestrator(model: model, registry: registry, maxRounds: 2)
        do {
            _ = try await orch.process(userMessage: "Loop forever")
            Issue.record("Expected maxRoundsExceeded error")
        } catch OrchestratorError.maxRoundsExceeded {
            // Expected
        }
    }

    // MARK: - 6. testTimeoutEnforcement

    @Test func testTimeoutEnforcement() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()

        // Tool that delays longer than the timeout
        let slowTool = StubExecutor(
            definition: ToolDefinition(
                name: "slow_tool",
                description: "Slow",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            ),
            riskLevel: .safe,
            executeBlock: { id, _ in
                try await Task.sleep(for: .seconds(5))
                return ToolResult(toolUseId: id, content: "done", isError: false)
            }
        )
        try registry.register(slowTool)

        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "slow_tool"))

        let orch = makeOrchestrator(model: model, registry: registry, timeout: 0.1)
        do {
            _ = try await orch.process(userMessage: "Do something slow")
            Issue.record("Expected timeout error")
        } catch OrchestratorError.timeout {
            // Expected
        } catch is CancellationError {
            // Also acceptable — task cancellation propagated
        }
    }

    // MARK: - 7. testAbortCancellation

    @Test func testAbortCancellation() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()

        // Tool that blocks so abort can be called
        let blockingTool = StubExecutor(
            definition: ToolDefinition(
                name: "blocking_tool",
                description: "Blocking",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            ),
            riskLevel: .safe,
            executeBlock: { id, _ in
                try await Task.sleep(for: .seconds(5))
                return ToolResult(toolUseId: id, content: "done", isError: false)
            }
        )
        try registry.register(blockingTool)
        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "blocking_tool"))

        let orch = makeOrchestrator(model: model, registry: registry, timeout: 30)

        let processTask = Task {
            try await orch.process(userMessage: "Block me")
        }

        // Give the task a moment to start
        try await Task.sleep(for: .milliseconds(50))
        orch.abort()

        do {
            _ = try await processTask.value
            Issue.record("Expected cancellation or abort error")
        } catch OrchestratorError.cancelled {
            // Expected
        } catch is CancellationError {
            // Also acceptable
        } catch OrchestratorError.timeout {
            // Also acceptable if timeout fires first
        }
    }

    // MARK: - 8. testPolicyDeny

    @Test func testPolicyDeny() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "dangerous_tool"))

        let policy = MockPolicyEngine()
        policy.overrides["dangerous_tool"] = .deny

        // Round 1: Claude requests tool
        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "dangerous_tool"))
        // Round 2: Claude sees denied error and responds
        model.enqueue(response: textResponse("I cannot do that."))

        let orch = makeOrchestrator(model: model, registry: registry, policy: policy)
        let result = try await orch.process(userMessage: "Do dangerous thing")

        #expect(result.text == "I cannot do that.")
        // Policy was evaluated
        #expect(policy.evaluatedCalls.count == 1)
        // Tool was not in toolsUsed (it was denied)
        #expect(!result.metrics.toolsUsed.contains("dangerous_tool"))
    }

    // MARK: - 9. testPolicyRequiresConfirmation_Approved

    @Test func testPolicyRequiresConfirmation_Approved() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "confirm_tool", result: "executed"))

        let policy = MockPolicyEngine()
        policy.overrides["confirm_tool"] = .requireConfirmation

        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "confirm_tool"))
        model.enqueue(response: textResponse("Done with confirmation"))

        // Approval handler returns true
        let orch = makeOrchestrator(
            model: model,
            registry: registry,
            policy: policy,
            confirmationHandler: { _ in true }
        )
        let result = try await orch.process(userMessage: "Do confirmed thing")

        #expect(result.text == "Done with confirmation")
        // Tool WAS executed (approved)
        #expect(result.metrics.toolsUsed.contains("confirm_tool"))
    }

    // MARK: - 10. testPolicyRequiresConfirmation_Rejected

    @Test func testPolicyRequiresConfirmation_Rejected() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()
        try registry.register(makeStubTool(name: "confirm_tool"))

        let policy = MockPolicyEngine()
        policy.overrides["confirm_tool"] = .requireConfirmation

        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "confirm_tool"))
        model.enqueue(response: textResponse("I cannot do that, you rejected it."))

        // Approval handler returns false
        let orch = makeOrchestrator(
            model: model,
            registry: registry,
            policy: policy,
            confirmationHandler: { _ in false }
        )
        let result = try await orch.process(userMessage: "Do confirmed thing")

        #expect(result.text == "I cannot do that, you rejected it.")
        // Tool was NOT executed
        #expect(!result.metrics.toolsUsed.contains("confirm_tool"))
    }

    // MARK: - 11. testToolExecutionError

    @Test func testToolExecutionError() async throws {
        let model = MockModelProvider()
        let registry = ToolRegistryImpl()

        struct ToolError: Error {}
        let errorTool = StubExecutor(
            definition: ToolDefinition(
                name: "error_tool",
                description: "Always errors",
                inputSchema: .object(["type": .string("object"), "properties": .object([:])])
            ),
            riskLevel: .safe,
            executeBlock: { _, _ in throw ToolError() }
        )
        try registry.register(errorTool)

        model.enqueue(response: toolUseResponse(toolId: "tu-1", toolName: "error_tool"))
        model.enqueue(response: textResponse("The tool failed, I'll handle it."))

        let orch = makeOrchestrator(model: model, registry: registry)
        let result = try await orch.process(userMessage: "Try the error tool")

        // Should not throw — error wrapped in ToolResult and sent back to Claude
        #expect(result.text == "The tool failed, I'll handle it.")
        #expect(result.metrics.errorsEncountered == 1)
    }

    // MARK: - 12. testContextLockSetAndClear

    @Test func testContextLockSetAndClear() {
        let model = MockModelProvider()
        let orch = makeOrchestrator(model: model)

        #expect(orch.contextLock == nil)

        let lock = ContextLock(bundleId: "com.apple.Safari", pid: 1234)
        orch.setContextLock(lock)
        #expect(orch.contextLock == lock)

        orch.clearContextLock()
        #expect(orch.contextLock == nil)
    }
}
