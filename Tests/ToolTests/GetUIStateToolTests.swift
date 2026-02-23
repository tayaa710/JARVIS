import Testing
import CoreGraphics
@testable import JARVIS

@Suite("GetUIStateTool Tests")
struct GetUIStateToolTests {

    // MARK: - Helpers

    private func makeTool(service: MockAccessibilityService? = nil, cache: UIStateCache? = nil)
    -> (GetUIStateTool, MockAccessibilityService, UIStateCache) {
        let svc = service ?? MockAccessibilityService()
        svc.setDefaultSnapshot()
        let c = cache ?? UIStateCache()
        let tool = GetUIStateTool(accessibilityService: svc, cache: c)
        return (tool, svc, c)
    }

    private func execute(_ tool: GetUIStateTool, args: [String: JSONValue] = [:]) async throws -> ToolResult {
        try await tool.execute(id: "test-id", arguments: args)
    }

    // MARK: - Tests

    @Test("Returns formatted snapshot with @e refs")
    func returnsFormattedSnapshot() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool)
        #expect(!result.isError)
        #expect(result.content.contains("@e1"))
        #expect(result.content.contains("App: TestApp"))
    }

    @Test("Uses cached result on second call within TTL")
    func usesCacheOnSecondCall() async throws {
        let cache = UIStateCache(ttl: 60)
        let (tool, service, _) = makeTool(cache: cache)
        _ = try await execute(tool)
        _ = try await execute(tool)
        #expect(service.walkCallCount == 1)
    }

    @Test("Walks fresh tree after TTL expires")
    func walksFreshAfterTTL() async throws {
        let cache = UIStateCache(ttl: 0.05)
        let (tool, service, _) = makeTool(cache: cache)
        _ = try await execute(tool)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        _ = try await execute(tool)
        #expect(service.walkCallCount == 2)
    }

    @Test("Calls contextLockSetter with correct bundleId and pid")
    func callsContextLockSetter() async throws {
        let (tool, _, _) = makeTool()
        var capturedLock: ContextLock?
        tool.contextLockSetter = { lock in
            capturedLock = lock
        }
        _ = try await execute(tool)
        #expect(capturedLock?.bundleId == "com.test.app")
        #expect(capturedLock?.pid == 1234)
    }

    @Test("Returns error when no frontmost app")
    func returnsErrorWhenNoApp() async throws {
        let service = MockAccessibilityService()
        service.walkError = AXServiceError.noFrontmostApp
        let tool = GetUIStateTool(accessibilityService: service, cache: UIStateCache())
        let result = try await execute(tool)
        #expect(result.isError)
    }

    @Test("Optional max_depth argument is accepted")
    func acceptsMaxDepth() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["max_depth": .number(3)])
        #expect(!result.isError)
    }

    @Test("Optional max_elements argument is accepted")
    func acceptsMaxElements() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["max_elements": .number(50)])
        #expect(!result.isError)
    }

    @Test("Risk level is safe")
    func riskLevelIsSafe() {
        let (tool, _, _) = makeTool()
        #expect(tool.riskLevel == .safe)
    }

    @Test("Tool name is get_ui_state")
    func toolName() {
        let (tool, _, _) = makeTool()
        #expect(tool.definition.name == "get_ui_state")
    }
}
