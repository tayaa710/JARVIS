import Testing
import Foundation
@testable import JARVIS

@Suite("SystemInfoTool Tests")
struct SystemInfoToolTests {

    private let tool = SystemInfoTool()

    @Test func definitionNameIsSystemInfo() {
        #expect(tool.definition.name == "system_info")
    }

    @Test func definitionDescriptionIsNonEmpty() {
        #expect(!tool.definition.description.isEmpty)
    }

    @Test func riskLevelIsSafe() {
        #expect(tool.riskLevel == .safe)
    }

    @Test func executeReturnsNoError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.isError == false)
    }

    @Test func executeResultHasCorrectToolUseId() async throws {
        let result = try await tool.execute(id: "tu_abc", arguments: [:])
        #expect(result.toolUseId == "tu_abc")
    }

    @Test func resultContentContainsOSVersion() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        let hasVersion = result.content.contains("macOS") || result.content.contains("Version")
        #expect(hasVersion)
    }

    @Test func resultContentContainsNonEmptyHostname() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.content.contains("Hostname:"))
    }

    @Test func resultContentContainsUsername() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.content.contains("User:"))
    }

    @Test func inputSchemaEncodesToObjectType() throws {
        let data = try JSONEncoder().encode(tool.definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "object")
    }
}
