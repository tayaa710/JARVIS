import Testing
import Foundation
@testable import JARVIS

@Suite("AppOpenTool Tests")
struct AppOpenToolTests {

    private let tool = AppOpenTool()

    @Test func definitionNameIsAppOpen() {
        #expect(tool.definition.name == "app_open")
    }

    @Test func descriptionIsNonEmpty() {
        #expect(!tool.definition.description.isEmpty)
    }

    @Test func riskLevelIsCaution() {
        #expect(tool.riskLevel == .caution)
    }

    @Test func schemaEncodesToObjectType() throws {
        let data = try JSONEncoder().encode(tool.definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "object")
    }

    @Test func schemaHasRequiredName() throws {
        let data = try JSONEncoder().encode(tool.definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let required = json["required"] as? [String]
        #expect(required?.contains("name") == true)
    }

    @Test func missingNameReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func emptyNameReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: ["name": .string("")])
        #expect(result.isError == true)
    }

    @Test func openFinderReturnsSuccess() async throws {
        // Finder is always running on macOS; this activates it
        let result = try await tool.execute(id: "tu_test", arguments: ["name": .string("Finder")])
        #expect(result.isError == false)
        #expect(result.content.lowercased().contains("finder"))
    }
}
