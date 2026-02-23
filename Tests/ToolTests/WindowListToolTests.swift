import Testing
import Foundation
@testable import JARVIS

@Suite("WindowListTool Tests")
struct WindowListToolTests {

    private let tool = WindowListTool()

    @Test func definitionNameIsWindowList() {
        #expect(tool.definition.name == "window_list")
    }

    @Test func descriptionIsNonEmpty() {
        #expect(!tool.definition.description.isEmpty)
    }

    @Test func riskLevelIsSafe() {
        #expect(tool.riskLevel == .safe)
    }

    @Test func schemaEncodesToObjectType() throws {
        let data = try JSONEncoder().encode(tool.definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "object")
    }

    @Test func executeReturnsNoError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.isError == false)
    }

    @Test func resultContentIsNonEmpty() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        // Even in CI we always return either window entries or the "No visible windows" message
        #expect(!result.content.isEmpty)
    }
}
