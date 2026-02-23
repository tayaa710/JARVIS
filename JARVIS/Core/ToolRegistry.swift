enum ToolRegistryError: Error, Equatable {
    case duplicateToolName(String)
    case unknownTool(String)
    case validationFailed(String)
}

protocol ToolRegistry: Sendable {
    func register(_ executor: any ToolExecutor) throws
    func executor(for toolId: String) -> (any ToolExecutor)?
    func allDefinitions() -> [ToolDefinition]
    func validate(call: ToolUse) throws
    func dispatch(call: ToolUse) async throws -> ToolResult
}
