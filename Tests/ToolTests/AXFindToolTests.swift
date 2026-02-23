import Testing
import CoreGraphics
@testable import JARVIS

@Suite("AXFindTool Tests")
struct AXFindToolTests {

    // MARK: - Helpers

    private func makeSnapshot() -> UITreeSnapshot {
        let button = UIElementSnapshot(ref: "@e2", role: "AXButton", title: "Submit",
                                       value: nil, isEnabled: true, frame: .zero, children: [])
        let textField = UIElementSnapshot(ref: "@e3", role: "AXTextField", title: "Email",
                                          value: "user@example.com", isEnabled: true, frame: .zero, children: [])
        let disabledButton = UIElementSnapshot(ref: "@e4", role: "AXButton", title: "Cancel",
                                               value: nil, isEnabled: false, frame: .zero, children: [])
        let root = UIElementSnapshot(ref: "@e1", role: "AXApplication", title: "TestApp",
                                     value: nil, isEnabled: true, frame: .zero,
                                     children: [button, textField, disabledButton])
        return UITreeSnapshot(appName: "TestApp", bundleId: "com.test", pid: 1,
                              root: root, elementCount: 4, truncated: false)
    }

    private func makeService(withSnapshot: UITreeSnapshot? = nil) -> MockAccessibilityService {
        let service = MockAccessibilityService()
        service.walkResult = withSnapshot ?? makeSnapshot()
        return service
    }

    private func makeTool(service: MockAccessibilityService? = nil,
                          cache: UIStateCache? = nil) -> (AXFindTool, MockAccessibilityService, UIStateCache) {
        let svc = service ?? makeService()
        let c = cache ?? UIStateCache()
        return (AXFindTool(accessibilityService: svc, cache: c), svc, c)
    }

    private func execute(_ tool: AXFindTool, args: [String: JSONValue]) async throws -> ToolResult {
        try await tool.execute(id: "test-id", arguments: args)
    }

    // MARK: - Tests

    @Test("Find by role returns matching elements")
    func findByRole() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["role": .string("AXButton")])
        #expect(!result.isError)
        #expect(result.content.contains("@e2"))
        #expect(result.content.contains("@e4"))
        #expect(!result.content.contains("@e3"))
    }

    @Test("Find by title (substring, case-insensitive)")
    func findByTitle() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["title": .string("sub")])
        #expect(!result.isError)
        #expect(result.content.contains("@e2"))
        #expect(!result.content.contains("@e4"))
    }

    @Test("Find by value (substring, case-insensitive)")
    func findByValue() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["value": .string("example")])
        #expect(!result.isError)
        #expect(result.content.contains("@e3"))
    }

    @Test("Combined role + title narrows results")
    func combinedRoleAndTitle() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: [
            "role": .string("AXButton"),
            "title": .string("Submit")
        ])
        #expect(!result.isError)
        #expect(result.content.contains("@e2"))
        #expect(!result.content.contains("@e4"))
    }

    @Test("No matches returns descriptive message")
    func noMatchesReturnsMessage() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: ["title": .string("NonExistentElement")])
        #expect(!result.isError)
        #expect(result.content.contains("No elements found"))
    }

    @Test("At least one filter required")
    func atLeastOneFilterRequired() async throws {
        let (tool, _, _) = makeTool()
        let result = try await execute(tool, args: [:])
        #expect(result.isError)
    }

    @Test("Uses cached snapshot if available")
    func usesCachedSnapshot() async throws {
        let cache = UIStateCache(ttl: 60)
        let service = makeService()
        let snap = makeSnapshot()
        cache.set(result: "cached", snapshot: snap)
        let tool = AXFindTool(accessibilityService: service, cache: cache)
        _ = try await execute(tool, args: ["role": .string("AXButton")])
        // walkFrontmostApp should NOT have been called
        #expect(service.walkCallCount == 0)
    }

    @Test("Walks fresh tree if no cache")
    func walksFreshIfNoCache() async throws {
        let cache = UIStateCache()
        let service = makeService()
        let tool = AXFindTool(accessibilityService: service, cache: cache)
        _ = try await execute(tool, args: ["role": .string("AXButton")])
        #expect(service.walkCallCount == 1)
    }

    @Test("Tool name is ax_find")
    func toolName() {
        let (tool, _, _) = makeTool()
        #expect(tool.definition.name == "ax_find")
    }

    @Test("Risk level is safe")
    func riskLevelIsSafe() {
        let (tool, _, _) = makeTool()
        #expect(tool.riskLevel == .safe)
    }
}
