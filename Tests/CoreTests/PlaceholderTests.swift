import Testing
@testable import JARVIS

@Suite("Placeholder Tests")
struct PlaceholderTests {

    @Test func testProjectCompiles() {
        #expect(true)
    }

    @Test func testModelProviderProtocolConformance() {
        struct MockProvider: ModelProvider {
            func send(messages: [Message], tools: [ToolDefinition]) async throws -> Response {
                Response()
            }
            func sendStreaming(messages: [Message], tools: [ToolDefinition]) -> AsyncStream<StreamEvent> {
                AsyncStream { continuation in
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
            var definition: ToolDefinition { ToolDefinition() }
            func execute(arguments: [String: String]) async throws -> ToolResult {
                ToolResult()
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
            func validate(call: ToolCall) throws {}
            func dispatch(call: ToolCall) async throws -> ToolResult { ToolResult() }
        }
        let registry: any ToolRegistry = MockRegistry()
        #expect(registry is MockRegistry)
    }

    @Test func testPolicyEngineProtocolConformance() {
        struct MockPolicyEngine: PolicyEngine {
            func evaluate(call: ToolCall, riskLevel: RiskLevel) -> PolicyDecision {
                .allow
            }
        }
        let engine: any PolicyEngine = MockPolicyEngine()
        #expect(engine is MockPolicyEngine)
    }
}
