import Testing
@testable import JARVIS

@Suite("Placeholder Tests")
struct PlaceholderTests {

    @Test func testProjectCompiles() {
        #expect(true)
    }

    @Test func testModelProviderProtocolConformance() {
        struct MockProvider: ModelProvider {
            func send(messages: [Message], tools: [ToolDefinition], system: String?) async throws -> Response {
                Response(
                    id: "test",
                    model: "claude-opus-4-6",
                    content: [.text("hi")],
                    stopReason: .endTurn,
                    usage: Usage(inputTokens: 1, outputTokens: 1)
                )
            }
            func sendStreaming(messages: [Message], tools: [ToolDefinition], system: String?) -> AsyncThrowingStream<StreamEvent, Error> {
                AsyncThrowingStream { continuation in
                    continuation.finish()
                }
            }
            func abort() {}
        }
        let provider: any ModelProvider = MockProvider()
        #expect(provider is MockProvider)
    }

    @Test func testToolExecutorProtocolConformance() {
        struct MockExecutor: ToolExecutor {
            var definition: ToolDefinition {
                ToolDefinition(
                    name: "mock",
                    description: "A mock tool",
                    inputSchema: .object([:])
                )
            }
            func execute(arguments: [String: String]) async throws -> ToolResult {
                ToolResult(toolUseId: "tu_mock", content: "ok", isError: false)
            }
        }
        let executor: any ToolExecutor = MockExecutor()
        #expect(executor is MockExecutor)
    }

    @Test func testToolRegistryProtocolConformance() {
        struct MockRegistry: ToolRegistry {
            func register(_ executor: any ToolExecutor) throws {}
            func executor(for toolId: String) -> (any ToolExecutor)? { nil }
            func allDefinitions() -> [ToolDefinition] { [] }
            func validate(call: ToolUse) throws {}
            func dispatch(call: ToolUse) async throws -> ToolResult {
                ToolResult(toolUseId: call.id, content: "ok", isError: false)
            }
        }
        let registry: any ToolRegistry = MockRegistry()
        #expect(registry is MockRegistry)
    }

    @Test func testPolicyEngineProtocolConformance() {
        struct MockPolicyEngine: PolicyEngine {
            func evaluate(call: ToolUse, riskLevel: RiskLevel) -> PolicyDecision {
                .allow
            }
        }
        let engine: any PolicyEngine = MockPolicyEngine()
        #expect(engine is MockPolicyEngine)
    }
}
