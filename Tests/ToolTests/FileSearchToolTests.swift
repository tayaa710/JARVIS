import Testing
import Foundation
@testable import JARVIS

@Suite("FileSearchTool Tests")
struct FileSearchToolTests {

    private let tool = FileSearchTool()

    @Test func definitionNameIsFileSearch() {
        #expect(tool.definition.name == "file_search")
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

    @Test func missingQueryReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func findsKnownFileInTempDir() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileName = "known_\(UUID().uuidString).txt"
        let filePath = tempDir.appendingPathComponent(fileName)
        try "content".write(to: filePath, atomically: true, encoding: .utf8)

        let result = try await tool.execute(id: "tu_test", arguments: [
            "query": .string(fileName),
            "directory": .string(tempDir.path)
        ])
        #expect(result.isError == false)
        #expect(result.content.contains(fileName))
    }

    @Test func returnsNoFilesFoundWhenMissing() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = try await tool.execute(id: "tu_test", arguments: [
            "query": .string("nonexistent_\(UUID().uuidString).txt"),
            "directory": .string(tempDir.path)
        ])
        #expect(result.isError == false)
        #expect(result.content.contains("No files found"))
    }

    @Test func respectsResultsCap() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for i in 0..<110 {
            let filePath = tempDir.appendingPathComponent("captest_\(i).txt")
            try "x".write(to: filePath, atomically: true, encoding: .utf8)
        }

        let result = try await tool.execute(id: "tu_test", arguments: [
            "query": .string("captest_*.txt"),
            "directory": .string(tempDir.path)
        ])
        #expect(result.isError == false)
        #expect(result.content.contains("limited"))
    }
}
