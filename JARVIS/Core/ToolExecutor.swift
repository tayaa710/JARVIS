protocol ToolExecutor: Sendable {
    var definition: ToolDefinition { get }
    func execute(arguments: [String: String]) async throws -> ToolResult
}
