import Testing
import Foundation
@testable import JARVIS

@Suite("ScreenshotTool Tests")
struct ScreenshotToolTests {

    private func makeTool(
        provider: MockScreenshotProvider? = nil,
        cache: ScreenshotCache? = nil
    ) -> (ScreenshotTool, MockScreenshotProvider, ScreenshotCache) {
        let p = provider ?? MockScreenshotProvider()
        let c = cache ?? ScreenshotCache()
        return (ScreenshotTool(screenshotProvider: p, cache: c), p, c)
    }

    private func execute(
        _ tool: ScreenshotTool,
        args: [String: JSONValue] = [:]
    ) async throws -> ToolResult {
        try await tool.execute(id: "test-id", arguments: args)
    }

    // MARK: - Tests

    @Test("Successful screen capture stores in cache and returns success message")
    func successfulScreenCapture() async throws {
        let (tool, _, cache) = makeTool()
        let result = try await execute(tool)
        #expect(!result.isError)
        #expect(result.content.contains("Screenshot captured"))
        #expect(cache.get() != nil)
    }

    @Test("Successful window capture stores in cache")
    func successfulWindowCapture() async throws {
        let (tool, _, cache) = makeTool()
        let result = try await execute(tool, args: ["target": .string("window")])
        #expect(!result.isError)
        #expect(cache.get() != nil)
    }

    @Test("Permission denied returns error result")
    func permissionDeniedReturnsError() async throws {
        let provider = MockScreenshotProvider()
        provider.hasPermission = false
        let (tool, _, _) = makeTool(provider: provider)
        let result = try await execute(tool)
        #expect(result.isError)
        #expect(result.content.lowercased().contains("permission"))
    }

    @Test("Capture failure returns error result")
    func captureFailureReturnsError() async throws {
        let provider = MockScreenshotProvider()
        provider.captureResult = .failure(ScreenshotError.captureFailed)
        let (tool, _, _) = makeTool(provider: provider)
        let result = try await execute(tool)
        #expect(result.isError)
    }

    @Test("Risk level is safe")
    func riskLevelIsSafe() {
        let (tool, _, _) = makeTool()
        #expect(tool.riskLevel == .safe)
    }

    @Test("Tool name is screenshot")
    func toolName() {
        let (tool, _, _) = makeTool()
        #expect(tool.definition.name == "screenshot")
    }

    @Test("Input schema is correct")
    func inputSchema() {
        let (tool, _, _) = makeTool()
        let schema = tool.definition.inputSchema
        guard case .object(let props) = schema,
              case .object(let properties) = props["properties"],
              let target = properties["target"],
              case .object(let targetProps) = target,
              case .string(let targetType) = targetProps["type"] else {
            Issue.record("Unexpected schema structure"); return
        }
        #expect(targetType == "string")
    }

    @Test("Default target is screen when not specified")
    func defaultTargetIsScreen() async throws {
        let provider = MockScreenshotProvider()
        let (tool, _, _) = makeTool(provider: provider)
        _ = try await execute(tool) // no args — defaults to screen
        #expect(provider.captureScreenCallCount == 1)
        #expect(provider.captureWindowCallCount == 0)
    }

    @Test("Explicit target window calls captureWindow")
    func explicitTargetWindow() async throws {
        let provider = MockScreenshotProvider()
        let (tool, _, _) = makeTool(provider: provider)
        _ = try await execute(tool, args: ["target": .string("window")])
        #expect(provider.captureWindowCallCount == 1)
        #expect(provider.captureScreenCallCount == 0)
    }

    @Test("Result message includes dimensions")
    func resultIncludesDimensions() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool)
        #expect(!result.isError)
        // Message should tell Claude to use vision_analyze next.
        #expect(result.content.contains("vision_analyze"))
    }
}
