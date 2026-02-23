import Testing
import Foundation
import AppKit
@testable import JARVIS

// Helper: registers all 9 built-in tools in a fresh registry
private func makeFullRegistry() throws -> ToolRegistryImpl {
    let registry = ToolRegistryImpl()
    try registry.register(AppListTool())
    try registry.register(AppOpenTool())
    try registry.register(FileSearchTool())
    try registry.register(FileReadTool())
    try registry.register(FileWriteTool())
    try registry.register(ClipboardReadTool())
    try registry.register(ClipboardWriteTool())
    try registry.register(WindowListTool())
    try registry.register(WindowManageTool())
    return registry
}

@Suite("Clipboard Tool Tests", .serialized)
struct ClipboardToolTests {

    // MARK: - ClipboardReadTool

    @Test func clipboardReadDefinitionName() {
        #expect(ClipboardReadTool().definition.name == "clipboard_read")
    }

    @Test func clipboardReadDescriptionIsNonEmpty() {
        #expect(!ClipboardReadTool().definition.description.isEmpty)
    }

    @Test func clipboardReadRiskLevelIsSafe() {
        #expect(ClipboardReadTool().riskLevel == .safe)
    }

    @Test func clipboardReadSchemaEncodesToObjectType() throws {
        let data = try JSONEncoder().encode(ClipboardReadTool().definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "object")
    }

    @Test func clipboardReadReturnsEmptyMessageWhenNoString() async throws {
        NSPasteboard.general.clearContents()
        let result = try await ClipboardReadTool().execute(id: "tu_test", arguments: [:])
        #expect(result.isError == false)
        #expect(result.content == "Clipboard is empty")
    }

    @Test func clipboardReadReturnsKnownString() async throws {
        let uuid = UUID().uuidString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(uuid, forType: .string)
        let result = try await ClipboardReadTool().execute(id: "tu_test", arguments: [:])
        #expect(result.isError == false)
        #expect(result.content == uuid)
    }

    // MARK: - ClipboardWriteTool

    @Test func clipboardWriteDefinitionName() {
        #expect(ClipboardWriteTool().definition.name == "clipboard_write")
    }

    @Test func clipboardWriteDescriptionIsNonEmpty() {
        #expect(!ClipboardWriteTool().definition.description.isEmpty)
    }

    @Test func clipboardWriteRiskLevelIsCaution() {
        #expect(ClipboardWriteTool().riskLevel == .caution)
    }

    @Test func clipboardWriteSchemaEncodesToObjectType() throws {
        let data = try JSONEncoder().encode(ClipboardWriteTool().definition.inputSchema)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["type"] as? String == "object")
    }

    @Test func clipboardWriteMissingTextReturnsError() async throws {
        let result = try await ClipboardWriteTool().execute(id: "tu_test", arguments: [:])
        #expect(result.isError == true)
    }

    @Test func clipboardWriteWritesToPasteboard() async throws {
        let uuid = UUID().uuidString
        NSPasteboard.general.clearContents()
        let result = try await ClipboardWriteTool().execute(
            id: "tu_test",
            arguments: ["text": .string(uuid)]
        )
        #expect(result.isError == false)
        #expect(NSPasteboard.general.string(forType: .string) == uuid)
    }

    @Test func clipboardWriteThenReadRoundtrip() async throws {
        let uuid = UUID().uuidString
        let writeResult = try await ClipboardWriteTool().execute(
            id: "tu_w",
            arguments: ["text": .string(uuid)]
        )
        #expect(writeResult.isError == false)
        let readResult = try await ClipboardReadTool().execute(id: "tu_r", arguments: [:])
        #expect(readResult.content == uuid)
    }

    // MARK: - Integration: clipboard_write → clipboard_read via Orchestrator
    // Lives here (in the serialized suite) to prevent races with the unit tests above.

    @Test func orchestratorClipboardWriteThenRead() async throws {
        let model = MockModelProvider()
        let registry = try makeFullRegistry()
        let policy = PolicyEngineImpl(autonomyLevel: .fullAuto)

        let testValue = "JARVIS-integration-\(UUID().uuidString)"

        // Round 1: write to clipboard
        model.enqueue(response: Response(
            id: "resp-cw-1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(
                id: "tu-cw-1",
                name: "clipboard_write",
                input: ["text": .string(testValue)]
            ))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 25, outputTokens: 10)
        ))

        // Round 2: read from clipboard
        model.enqueue(response: Response(
            id: "resp-cr-1",
            model: "claude-sonnet-4-6",
            content: [.toolUse(ToolUse(id: "tu-cr-1", name: "clipboard_read", input: [:]))],
            stopReason: .toolUse,
            usage: Usage(inputTokens: 50, outputTokens: 10)
        ))

        // Round 3: final text
        model.enqueue(response: Response(
            id: "resp-cr-2",
            model: "claude-sonnet-4-6",
            content: [.text("Done: wrote and read the clipboard.")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 80, outputTokens: 12)
        ))

        let orch = OrchestratorImpl(
            modelProvider: model,
            toolRegistry: registry,
            policyEngine: policy
        )

        let result = try await orch.process(userMessage: "Write to clipboard then read it back")

        #expect(result.text == "Done: wrote and read the clipboard.")
        #expect(result.metrics.roundCount == 3)
        #expect(result.metrics.toolsUsed == ["clipboard_write", "clipboard_read"])
        #expect(result.metrics.errorsEncountered == 0)
        #expect(NSPasteboard.general.string(forType: .string) == testValue)

        // Clean up so the next test starts with a known state
        NSPasteboard.general.clearContents()
    }
}
