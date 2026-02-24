import Testing
import Foundation
@testable import JARVIS

/// Full-loop integration tests: orchestrator drives browser tool sequences.
@Suite("Browser Tools Integration Tests")
struct BrowserToolsIntegrationTests {

    // MARK: - Helpers

    private func makeRegistry(backend: MockBrowserBackend) throws -> ToolRegistryImpl {
        let registry = ToolRegistryImpl()
        try registerBrowserTools(in: registry, backend: backend)
        return registry
    }

    // MARK: - Tests

    @Test("Full loop: navigate then get_url returns URL")
    func navigateAndGetURL() async throws {
        let browserBackend = MockBrowserBackend()
        browserBackend.getURLResult = "https://example.com"
        let registry = try makeRegistry(backend: browserBackend)

        let model = MockModelProvider()
        // Round 1: Claude calls browser_navigate
        model.enqueue(response: Response(
            id: "msg_1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_1",
                name: "browser_navigate",
                input: ["url": .string("https://example.com")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 10)
        ))
        // Round 2: Claude calls browser_get_url
        model.enqueue(response: Response(
            id: "msg_2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_2",
                name: "browser_get_url",
                input: [:]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 25, outputTokens: 10)
        ))
        // Round 3: Claude responds with final text
        model.enqueue(response: Response(
            id: "msg_3",
            model: "claude-sonnet-4-6",
            content: [.text("You are now on https://example.com")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 30, outputTokens: 15)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: PolicyEngineImpl(),
            systemPrompt: nil
        )

        let result = try await orch.process(userMessage: "Go to example.com and tell me the URL.")
        #expect(result.text == "You are now on https://example.com")
        #expect(browserBackend.navigateCallCount == 1)
        #expect(browserBackend.getURLCallCount == 1)
        #expect(browserBackend.lastNavigateURL == "https://example.com")
    }

    @Test("Full loop: find element then click it")
    func findAndClickElement() async throws {
        let browserBackend = MockBrowserBackend()
        browserBackend.findElementResult = true
        let registry = try makeRegistry(backend: browserBackend)

        let model = MockModelProvider()
        // Round 1: Claude calls browser_find_element
        model.enqueue(response: Response(
            id: "msg_1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_1",
                name: "browser_find_element",
                input: ["selector": .string("button#submit")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 10)
        ))
        // Round 2: Claude calls browser_click
        model.enqueue(response: Response(
            id: "msg_2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_2",
                name: "browser_click",
                input: ["selector": .string("button#submit")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 25, outputTokens: 10)
        ))
        // Round 3: final text
        model.enqueue(response: Response(
            id: "msg_3",
            model: "claude-sonnet-4-6",
            content: [.text("I found and clicked the submit button.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 30, outputTokens: 15)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: PolicyEngineImpl(),
            systemPrompt: nil
        )

        let result = try await orch.process(userMessage: "Click the submit button.")
        #expect(result.text == "I found and clicked the submit button.")
        #expect(browserBackend.findElementCallCount == 1)
        #expect(browserBackend.clickElementCallCount == 1)
        #expect(browserBackend.lastClickElementSelector == "button#submit")
    }

    @Test("Browser tool error handled gracefully by orchestrator")
    func browserToolErrorHandledGracefully() async throws {
        let browserBackend = MockBrowserBackend()
        browserBackend.navigateShouldThrow = BrowserError.noBrowserDetected
        let registry = try makeRegistry(backend: browserBackend)

        let model = MockModelProvider()
        // Round 1: Claude calls browser_navigate (will fail)
        model.enqueue(response: Response(
            id: "msg_1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_1",
                name: "browser_navigate",
                input: ["url": .string("https://example.com")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 10)
        ))
        // Round 2: Claude sees the error in tool_result and adapts
        model.enqueue(response: Response(
            id: "msg_2",
            model: "claude-sonnet-4-6",
            content: [.text("It seems no browser is open. Please open Safari or Chrome and try again.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 30, outputTokens: 20)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: PolicyEngineImpl(),
            systemPrompt: nil
        )

        let result = try await orch.process(userMessage: "Navigate to example.com")
        // Orchestrator should complete (not crash) and Claude's adaptive response is the final text
        #expect(result.text.contains("browser") || result.text.contains("Safari") || result.text.contains("Chrome"))
        #expect(browserBackend.navigateCallCount == 1)
    }
}
