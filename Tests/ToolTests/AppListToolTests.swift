import Testing
import Foundation
@testable import JARVIS

@Suite("AppListTool Tests")
struct AppListToolTests {

    private let tool = AppListTool()

    @Test func definitionNameIsAppList() {
        #expect(tool.definition.name == "app_list")
    }

    @Test func definitionDescriptionIsNonEmpty() {
        #expect(!tool.definition.description.isEmpty)
    }

    @Test func riskLevelIsSafe() {
        #expect(tool.riskLevel == .safe)
    }

    @Test func inputSchemaEncodesToObjectType() throws {
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
        #expect(!result.content.isEmpty)
    }
}
