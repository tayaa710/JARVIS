import Foundation

// MARK: - VisionAnalyzeTool

/// Analyzes the most recent screenshot using Claude's vision.
/// Requires a prior call to the `screenshot` tool.
final class VisionAnalyzeTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "vision_analyze",
        description: """
        Analyzes the most recent screenshot using Claude's vision. Call screenshot first, \
        then use this tool with a question about what you see. Example queries: \
        'Where is the Submit button?', 'What text is visible?', 'Describe the layout.'
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("What to analyze or find in the screenshot.")
                ])
            ]),
            "required": .array([.string("query")])
        ])
    )

    let riskLevel: RiskLevel = .caution

    private let cache: ScreenshotCache
    private let modelProvider: any ModelProvider

    private static let systemPrompt =
        "You are analyzing a screenshot of a macOS screen. Answer the user's question concisely."

    init(cache: ScreenshotCache, modelProvider: any ModelProvider) {
        self.cache = cache
        self.modelProvider = modelProvider
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let entry = cache.get() else {
            return ToolResult(
                toolUseId: id,
                content: "No screenshot available. Call screenshot first, then use vision_analyze.",
                isError: true
            )
        }

        let query: String
        if case .string(let q) = arguments["query"] {
            query = q
        } else {
            query = "Describe what you see in this screenshot."
        }

        let imageBlock = ContentBlock.image(
            ImageContent(mediaType: entry.mediaType, base64Data: entry.data.base64EncodedString())
        )
        let textBlock = ContentBlock.text("Analyze this screenshot: \(query)")
        let message = Message(role: .user, content: [imageBlock, textBlock])

        do {
            let response = try await modelProvider.send(
                messages: [message],
                tools: [],
                system: Self.systemPrompt
            )

            // Extract first text block from response.
            let text = response.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.first

            guard let analysisText = text, !analysisText.isEmpty else {
                return ToolResult(
                    toolUseId: id,
                    content: "Vision analysis returned no text response.",
                    isError: true
                )
            }

            Logger.screenshot.info("Vision analysis complete for query: \(query)")
            return ToolResult(toolUseId: id, content: analysisText, isError: false)

        } catch {
            Logger.screenshot.error("Vision analysis failed: \(error)")
            return ToolResult(
                toolUseId: id,
                content: "Vision analysis failed: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
