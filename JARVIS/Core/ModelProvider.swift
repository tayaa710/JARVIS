protocol ModelProvider: Sendable {
    func send(messages: [Message], tools: [ToolDefinition], system: String?) async throws -> Response
    func sendStreaming(messages: [Message], tools: [ToolDefinition], system: String?) -> AsyncThrowingStream<StreamEvent, Error>
    func abort()
}
