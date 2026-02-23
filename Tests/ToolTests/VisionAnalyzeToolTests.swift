import Testing
import Foundation
@testable import JARVIS

@Suite("VisionAnalyzeTool Tests")
struct VisionAnalyzeToolTests {

    private func makeResponse(text: String) -> Response {
        Response(
            id: "msg_test",
            model: "claude-sonnet-4-6",
            content: [.text(text)],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 10, outputTokens: 20)
        )
    }

    private func makeCache(with data: Data = MockScreenshotProvider.makeTestImageData()) -> ScreenshotCache {
        let cache = ScreenshotCache(ttl: 60)
        cache.set(data: data, mediaType: "image/jpeg", width: 100, height: 100)
        return cache
    }

    private func execute(
        _ tool: VisionAnalyzeTool,
        query: String = "What do you see?"
    ) async throws -> ToolResult {
        try await tool.execute(id: "test-id", arguments: ["query": .string(query)])
    }

    // MARK: - Tests

    @Test("Valid cache returns analysis text from mock model")
    func validCacheReturnsAnalysis() async throws {
        let model = MockModelProvider()
        model.enqueue(response: makeResponse(text: "I see a red square."))
        let tool = VisionAnalyzeTool(cache: makeCache(), modelProvider: model)
        let result = try await execute(tool)
        #expect(!result.isError)
        #expect(result.content == "I see a red square.")
    }

    @Test("Empty cache returns error")
    func emptyCacheReturnsError() async throws {
        let model = MockModelProvider()
        let tool = VisionAnalyzeTool(cache: ScreenshotCache(ttl: 60), modelProvider: model)
        let result = try await execute(tool)
        #expect(result.isError)
        #expect(result.content.contains("screenshot"))
    }

    @Test("Expired cache returns error")
    func expiredCacheReturnsError() async throws {
        let model = MockModelProvider()
        let cache = ScreenshotCache(ttl: 0.01)
        cache.set(data: MockScreenshotProvider.makeTestImageData(),
                  mediaType: "image/jpeg", width: 100, height: 100)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        let tool = VisionAnalyzeTool(cache: cache, modelProvider: model)
        let result = try await execute(tool)
        #expect(result.isError)
    }

    @Test("Query is included in message sent to model")
    func queryIsIncludedInMessage() async throws {
        let model = MockModelProvider()
        model.enqueue(response: makeResponse(text: "Answer."))
        let tool = VisionAnalyzeTool(cache: makeCache(), modelProvider: model)
        _ = try await execute(tool, query: "Where is the Save button?")
        let lastMessage = model.lastMessages?.first
        let hasQuery = lastMessage?.content.contains { block in
            if case .text(let t) = block { return t.contains("Where is the Save button?") }
            return false
        }
        #expect(hasQuery == true)
    }

    @Test("Image content is in message sent to model")
    func imageContentIsInMessage() async throws {
        let model = MockModelProvider()
        model.enqueue(response: makeResponse(text: "Image analysis."))
        let tool = VisionAnalyzeTool(cache: makeCache(), modelProvider: model)
        _ = try await execute(tool)
        let lastMessage = model.lastMessages?.first
        let hasImage = lastMessage?.content.contains { block in
            if case .image = block { return true }
            return false
        }
        #expect(hasImage == true)
    }

    @Test("Model is called with no tools (prevents recursion)")
    func modelCalledWithNoTools() async throws {
        let model = MockModelProvider()
        model.enqueue(response: makeResponse(text: "OK."))
        let tool = VisionAnalyzeTool(cache: makeCache(), modelProvider: model)
        _ = try await execute(tool)
        #expect(model.lastTools?.isEmpty == true)
    }

    @Test("Model failure returns error result")
    func modelFailureReturnsError() async throws {
        let model = MockModelProvider()
        // Don't enqueue anything — MockModelProvider will fatalError on empty queue,
        // so simulate failure via an error-containing response.
        model.enqueue(response: Response(
            id: "msg_err",
            model: "claude-sonnet-4-6",
            content: [],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 1, outputTokens: 0)
        ))
        let tool = VisionAnalyzeTool(cache: makeCache(), modelProvider: model)
        let result = try await execute(tool)
        #expect(result.isError)
        #expect(result.content.contains("no text"))
    }

    @Test("Risk level is caution")
    func riskLevelIsCaution() {
        let tool = VisionAnalyzeTool(cache: ScreenshotCache(), modelProvider: MockModelProvider())
        #expect(tool.riskLevel == .caution)
    }

    @Test("Tool name is vision_analyze")
    func toolName() {
        let tool = VisionAnalyzeTool(cache: ScreenshotCache(), modelProvider: MockModelProvider())
        #expect(tool.definition.name == "vision_analyze")
    }

    @Test("Input schema requires query field")
    func inputSchemaRequiresQuery() {
        let tool = VisionAnalyzeTool(cache: ScreenshotCache(), modelProvider: MockModelProvider())
        guard case .object(let props) = tool.definition.inputSchema,
              case .array(let required) = props["required"] else {
            Issue.record("Unexpected schema structure"); return
        }
        #expect(required.contains(.string("query")))
    }
}
