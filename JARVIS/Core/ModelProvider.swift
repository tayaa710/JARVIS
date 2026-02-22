protocol ModelProvider: Sendable {
    func send(messages: [Message], tools: [ToolDefinition]) async throws -> Response
    func sendStreaming(messages: [Message], tools: [ToolDefinition]) -> AsyncStream<StreamEvent>
    func abort()
}
