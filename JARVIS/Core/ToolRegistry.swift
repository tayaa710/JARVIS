protocol ToolRegistry: Sendable {
    func register(_ executor: any ToolExecutor) throws
    func executor(for toolId: String) -> (any ToolExecutor)?
    func allDefinitions() -> [ToolDefinition]
    func validate(call: ToolCall) throws
    func dispatch(call: ToolCall) async throws -> ToolResult
}
