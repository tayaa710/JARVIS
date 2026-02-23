import Testing
import Foundation
@testable import JARVIS

// MARK: - Stub

private struct StubToolExecutor: ToolExecutor {
    let definition: ToolDefinition
    let riskLevel: RiskLevel
    let executeBlock: @Sendable (String, [String: JSONValue]) async throws -> ToolResult

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        try await executeBlock(id, arguments)
    }
}

private func makeStub(
    name: String,
    schema: JSONValue = .object(["type": .string("object")]),
    riskLevel: RiskLevel = .safe,
    result: String = "ok"
) -> StubToolExecutor {
    StubToolExecutor(
        definition: ToolDefinition(name: name, description: "stub \(name)", inputSchema: schema),
        riskLevel: riskLevel,
        executeBlock: { id, _ in ToolResult(toolUseId: id, content: result, isError: false) }
    )
}

// MARK: - Tests

@Suite("ToolRegistryImpl Tests")
struct ToolRegistryTests {

    // MARK: Registration

    @Test func registerToolAndLookUpByName() throws {
        let registry = ToolRegistryImpl()
        let stub = makeStub(name: "alpha")
        try registry.register(stub)
        let found = registry.executor(for: "alpha")
        #expect(found != nil)
    }

    @Test func registerToolAppearsInAllDefinitions() throws {
        let registry = ToolRegistryImpl()
        let stub = makeStub(name: "beta")
        try registry.register(stub)
        let defs = registry.allDefinitions()
        #expect(defs.map(\.name).contains("beta"))
    }

    @Test func registerDuplicateNameThrows() throws {
        let registry = ToolRegistryImpl()
        try registry.register(makeStub(name: "gamma"))
        #expect(throws: ToolRegistryError.duplicateToolName("gamma")) {
            try registry.register(makeStub(name: "gamma"))
        }
    }

    @Test func executorForUnknownNameReturnsNil() {
        let registry = ToolRegistryImpl()
        #expect(registry.executor(for: "no_such_tool") == nil)
    }

    @Test func allDefinitionsReturnsAllRegisteredTools() throws {
        let registry = ToolRegistryImpl()
        try registry.register(makeStub(name: "tool_one"))
        try registry.register(makeStub(name: "tool_two"))
        try registry.register(makeStub(name: "tool_three"))
        let names = registry.allDefinitions().map(\.name).sorted()
        #expect(names == ["tool_one", "tool_three", "tool_two"])
    }

    // MARK: Validate

    @Test func validateSucceedsForValidToolCall() throws {
        let registry = ToolRegistryImpl()
        let schema = JSONValue.object([
            "type": .string("object"),
            "properties": .object(["query": .object(["type": .string("string")])]),
            "required": .array([.string("query")])
        ])
        try registry.register(makeStub(name: "search", schema: schema))
        let call = ToolUse(id: "tu_1", name: "search", input: ["query": .string("hello")])
        try registry.validate(call: call)
    }

    @Test func validateUnknownToolThrows() {
        let registry = ToolRegistryImpl()
        let call = ToolUse(id: "tu_1", name: "ghost", input: [:])
        #expect(throws: ToolRegistryError.unknownTool("ghost")) {
            try registry.validate(call: call)
        }
    }

    @Test func validateMissingRequiredArgumentThrowsValidationFailed() throws {
        let registry = ToolRegistryImpl()
        let schema = JSONValue.object([
            "type": .string("object"),
            "properties": .object(["query": .object(["type": .string("string")])]),
            "required": .array([.string("query")])
        ])
        try registry.register(makeStub(name: "search", schema: schema))
        let call = ToolUse(id: "tu_1", name: "search", input: [:])
        #expect(throws: ToolRegistryError.self) {
            try registry.validate(call: call)
        }
    }

    @Test func validateWrongArgumentTypeThrowsValidationFailed() throws {
        let registry = ToolRegistryImpl()
        let schema = JSONValue.object([
            "type": .string("object"),
            "properties": .object(["count": .object(["type": .string("number")])])
        ])
        try registry.register(makeStub(name: "counter", schema: schema))
        let call = ToolUse(id: "tu_1", name: "counter", input: ["count": .string("not a number")])
        #expect(throws: ToolRegistryError.self) {
            try registry.validate(call: call)
        }
    }

    // MARK: Dispatch

    @Test func dispatchCallsCorrectExecutorAndReturnsResult() async throws {
        let registry = ToolRegistryImpl()
        let stub = StubToolExecutor(
            definition: ToolDefinition(name: "echo", description: "echo", inputSchema: .object(["type": .string("object")])),
            riskLevel: .safe,
            executeBlock: { id, args in
                let msg = args["msg"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
                return ToolResult(toolUseId: id, content: "echoed: \(msg)", isError: false)
            }
        )
        try registry.register(stub)
        let call = ToolUse(id: "tu_echo", name: "echo", input: ["msg": .string("hello")])
        let result = try await registry.dispatch(call: call)
        #expect(result.toolUseId == "tu_echo")
        #expect(result.content == "echoed: hello")
        #expect(result.isError == false)
    }

    @Test func dispatchUnknownToolThrows() async {
        let registry = ToolRegistryImpl()
        let call = ToolUse(id: "tu_1", name: "unknown", input: [:])
        await #expect(throws: ToolRegistryError.unknownTool("unknown")) {
            _ = try await registry.dispatch(call: call)
        }
    }

    @Test func dispatchWrapsExecutorErrorsInToolResult() async throws {
        let registry = ToolRegistryImpl()
        struct BoomError: Error { let message: String }
        let stub = StubToolExecutor(
            definition: ToolDefinition(name: "boom", description: "explodes", inputSchema: .object(["type": .string("object")])),
            riskLevel: .safe,
            executeBlock: { _, _ in throw BoomError(message: "kaboom") }
        )
        try registry.register(stub)
        let call = ToolUse(id: "tu_boom", name: "boom", input: [:])
        let result = try await registry.dispatch(call: call)
        #expect(result.toolUseId == "tu_boom")
        #expect(result.isError == true)
        #expect(result.content.contains("Tool execution failed"))
    }

    // MARK: ToolDefinition JSON format

    @Test func toolDefinitionSerializesToAnthropicAPIFormat() throws {
        let def = ToolDefinition(
            name: "test_tool",
            description: "A test tool",
            inputSchema: .object(["type": .string("object"), "properties": .object([:])])
        )
        let data = try JSONEncoder().encode(def)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["name"] as? String == "test_tool")
        #expect(json["description"] as? String == "A test tool")
        #expect(json["input_schema"] != nil)
        #expect(json["inputSchema"] == nil)

        // Round-trip
        let decoded = try JSONDecoder().decode(ToolDefinition.self, from: data)
        #expect(decoded.name == "test_tool")
        #expect(decoded.description == "A test tool")
    }
}
