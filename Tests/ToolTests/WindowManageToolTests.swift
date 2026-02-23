import Testing
import Foundation
@testable import JARVIS

@Suite("WindowManageTool Tests")
struct WindowManageToolTests {

    private let tool = WindowManageTool()

    @Test func definitionNameIsWindowManage() {
        #expect(tool.definition.name == "window_manage")
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

    @Test func schemaHasRequiredFields() throws {
        let data = try JSONEncoder().encode(tool.definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let required = json["required"] as? [String]
        #expect(required?.contains("action") == true)
        #expect(required?.contains("app_name") == true)
    }

    @Test func missingActionReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "app_name": .string("Finder")
        ])
        #expect(result.isError == true)
    }

    @Test func invalidActionReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("fly"),
            "app_name": .string("Finder")
        ])
        #expect(result.isError == true)
    }

    @Test func missingAppNameReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("minimize")
        ])
        #expect(result.isError == true)
    }

    @Test func moveWithoutXReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("move"),
            "app_name": .string("Finder"),
            "y": .number(100)
        ])
        #expect(result.isError == true)
    }

    @Test func moveWithoutYReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("move"),
            "app_name": .string("Finder"),
            "x": .number(100)
        ])
        #expect(result.isError == true)
    }

    @Test func resizeWithoutWidthReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("resize"),
            "app_name": .string("Finder"),
            "height": .number(400)
        ])
        #expect(result.isError == true)
    }

    @Test func resizeWithoutHeightReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "action": .string("resize"),
            "app_name": .string("Finder"),
            "width": .number(800)
        ])
        #expect(result.isError == true)
    }
}
