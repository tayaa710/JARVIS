import Testing
import Foundation
@testable import JARVIS

@Suite("FileReadTool Tests")
struct FileReadToolTests {

    private let tool = FileReadTool()

    @Test func definitionNameIsFileRead() {
        #expect(tool.definition.name == "file_read")
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

    @Test func missingPathReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func readsKnownTempFile() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        let content = "Hello from JARVIS test \(UUID().uuidString)"
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(tempFile.path)
        ])
        #expect(result.isError == false)
        #expect(result.content == content)
    }

    @Test func fileNotFoundReturnsError() async throws {
        let fakePath = "/tmp/nonexistent_\(UUID().uuidString).txt"
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(fakePath)
        ])
        #expect(result.isError == true)
        #expect(result.content.contains("not found") || result.content.contains("does not exist"))
    }

    @Test func pathTraversalBlocked() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("../etc/passwd")
        ])
        #expect(result.isError == true)
    }

    @Test func systemPathBlocked() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("/System/Library/foo.txt")
        ])
        #expect(result.isError == true)
    }

    @Test func relativePathBlocked() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("relative/path.txt")
        ])
        #expect(result.isError == true)
    }

    @Test func sizeLimitEnforced() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        // Write 2 MB of data
        let twoMB = 2 * 1024 * 1024
        let data = Data(repeating: 0x41, count: twoMB)
        try data.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(tempFile.path)
        ])
        #expect(result.isError == true)
        #expect(result.content.lowercased().contains("size") || result.content.lowercased().contains("large") || result.content.lowercased().contains("limit"))
    }
}
