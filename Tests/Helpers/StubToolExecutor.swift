import Foundation
@testable import JARVIS

// StubExecutor is a shared, configurable test helper for ToolExecutor.
// Used by OrchestratorTests and OrchestratorIntegrationTests.
// Note: named StubExecutor (not StubToolExecutor) to avoid conflict with the
// private StubToolExecutor defined in ToolRegistryTests.swift.
struct StubExecutor: ToolExecutor, Sendable {
    let definition: ToolDefinition
    let riskLevel: RiskLevel
    let executeBlock: @Sendable (String, [String: JSONValue]) async throws -> ToolResult

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        try await executeBlock(id, arguments)
    }
}

// Convenience factory: makes a stub that returns a fixed success string.
func makeStubTool(
    name: String,
    schema: JSONValue = .object(["type": .string("object"), "properties": .object([:])]),
    riskLevel: RiskLevel = .safe,
    result: String = "ok"
) -> StubExecutor {
    StubExecutor(
        definition: ToolDefinition(
            name: name,
            description: "Stub tool: \(name)",
            inputSchema: schema
        ),
        riskLevel: riskLevel,
        executeBlock: { id, _ in
            ToolResult(toolUseId: id, content: result, isError: false)
        }
    )
}
