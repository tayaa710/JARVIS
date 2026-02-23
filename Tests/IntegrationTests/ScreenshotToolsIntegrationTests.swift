import Testing
import Foundation
@testable import JARVIS

/// Full-loop integration test: orchestrator drives screenshot → vision_analyze sequence.
@Suite("Screenshot Tools Integration Tests")
struct ScreenshotToolsIntegrationTests {

    // MARK: - Helpers

    private func makeRegistry(
        screenshotProvider: MockScreenshotProvider,
        cache: ScreenshotCache,
        visionProvider: MockModelProvider
    ) throws -> ToolRegistryImpl {
        let registry = ToolRegistryImpl()
        try registry.register(ScreenshotTool(screenshotProvider: screenshotProvider, cache: cache))
        try registry.register(VisionAnalyzeTool(cache: cache, modelProvider: visionProvider))
        return registry
    }

    // MARK: - Tests

    @Test("Full loop: screenshot then vision_analyze returns analysis")
    func screenshotThenVisionAnalyze() async throws {
        let screenshotProvider = MockScreenshotProvider()
        let cache = ScreenshotCache(ttl: 60)
        let visionModel = MockModelProvider()
        visionModel.enqueue(response: Response(
            id: "msg_vision",
            model: "claude-sonnet-4-6",
            content: [.text("I see a red square in the center.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 50, outputTokens: 20)
        ))

        let registry = try makeRegistry(
            screenshotProvider: screenshotProvider,
            cache: cache,
            visionProvider: visionModel
        )

        // Orchestrator model: first returns screenshot tool_use, then vision_analyze tool_use,
        // then final text.
        let orchModel = MockModelProvider()
        orchModel.enqueue(response: Response(
            id: "msg_1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu_1", name: "screenshot", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 20, outputTokens: 10)
        ))
        orchModel.enqueue(response: Response(
            id: "msg_2",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu_2",
                name: "vision_analyze",
                input: ["query": .string("What is in the screenshot?")]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 30, outputTokens: 15)
        ))
        orchModel.enqueue(response: Response(
            id: "msg_3",
            model: "claude-sonnet-4-6",
            content: [.text("The screenshot shows a red square.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 40, outputTokens: 20)
        ))

        let policyEngine = PolicyEngineImpl()
        let orch = OrchestratorImpl(
            modelProvider: orchModel,
            toolRegistry: registry,
            policyEngine: policyEngine,
            systemPrompt: nil
        )

        let result = try await orch.process(userMessage: "Analyze the screen.")
        #expect(result.text == "The screenshot shows a red square.")
        #expect(screenshotProvider.captureScreenCallCount == 1)
        // vision model was called once for the analyze step
        #expect(visionModel.sendCallCount == 1)
    }

    @Test("Screenshot tool stores data in cache that vision_analyze can read")
    func cacheSharedBetweenTools() async throws {
        let screenshotProvider = MockScreenshotProvider()
        let cache = ScreenshotCache(ttl: 60)
        let visionModel = MockModelProvider()
        visionModel.enqueue(response: Response(
            id: "msg_v",
            model: "claude-sonnet-4-6",
            content: [.text("Analysis complete.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 5, outputTokens: 5)
        ))

        let registry = try makeRegistry(
            screenshotProvider: screenshotProvider,
            cache: cache,
            visionProvider: visionModel
        )

        // Execute screenshot tool directly.
        let screenshotTool = ScreenshotTool(screenshotProvider: screenshotProvider, cache: cache)
        let screenshotResult = try await screenshotTool.execute(id: "s1", arguments: [:])
        #expect(!screenshotResult.isError)
        #expect(cache.get() != nil)

        // Execute vision_analyze tool directly using the same cache.
        let visionTool = VisionAnalyzeTool(cache: cache, modelProvider: visionModel)
        let visionResult = try await visionTool.execute(
            id: "v1",
            arguments: ["query": .string("What is visible?")]
        )
        #expect(!visionResult.isError)
        #expect(visionResult.content == "Analysis complete.")

        // Verify the vision model received an image content block.
        let lastMessage = visionModel.lastMessages?.first
        let hasImage = lastMessage?.content.contains { block in
            if case .image = block { return true }
            return false
        }
        #expect(hasImage == true)
        _ = registry // suppress unused warning
    }

    @Test("Vision analyze without prior screenshot returns error")
    func visionAnalyzeWithoutScreenshot() async throws {
        let cache = ScreenshotCache(ttl: 60) // empty cache
        let visionModel = MockModelProvider()
        let tool = VisionAnalyzeTool(cache: cache, modelProvider: visionModel)
        let result = try await tool.execute(
            id: "v1",
            arguments: ["query": .string("What is there?")]
        )
        #expect(result.isError)
    }
}
