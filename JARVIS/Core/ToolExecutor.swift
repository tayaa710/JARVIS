protocol ToolExecutor: Sendable {
    var definition: ToolDefinition { get }
    var riskLevel: RiskLevel { get }
    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult
}
