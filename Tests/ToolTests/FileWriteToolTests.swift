import Testing
import Foundation
@testable import JARVIS

@Suite("FileWriteTool Tests")
struct FileWriteToolTests {

    private let tool = FileWriteTool()

    @Test func definitionNameIsFileWrite() {
        #expect(tool.definition.name == "file_write")
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

    @Test func missingPathReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "content": .string("hello")
        ])
        #expect(result.isError == true)
    }

    @Test func missingContentReturnsError() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("/tmp/test.txt")
        ])
        #expect(result.isError == true)
    }

    @Test func writesContentToTempFile() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let text = "Hello from JARVIS \(UUID().uuidString)"
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(tempFile.path),
            "content": .string(text)
        ])
        #expect(result.isError == false)
        let written = try String(contentsOf: tempFile, encoding: .utf8)
        #expect(written == text)
    }

    @Test func createsParentDirectories() async throws {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let deepFile = baseDir
            .appendingPathComponent("a/b/c")
            .appendingPathComponent("deep.txt")
        defer { try? FileManager.default.removeItem(at: baseDir) }

        let text = "deep content"
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(deepFile.path),
            "content": .string(text)
        ])
        #expect(result.isError == false)
        let written = try String(contentsOf: deepFile, encoding: .utf8)
        #expect(written == text)
    }

    @Test func pathTraversalBlocked() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("../tmp/evil.txt"),
            "content": .string("evil")
        ])
        #expect(result.isError == true)
    }

    @Test func systemPathBlocked() async throws {
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string("/usr/local/bin/evil"),
            "content": .string("evil")
        ])
        #expect(result.isError == true)
    }

    @Test func overwritesExistingFile() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        try "original".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let newContent = "overwritten"
        let result = try await tool.execute(id: "tu_test", arguments: [
            "path": .string(tempFile.path),
            "content": .string(newContent)
        ])
        #expect(result.isError == false)
        let written = try String(contentsOf: tempFile, encoding: .utf8)
        #expect(written == newContent)
    }
}
