import Foundation

// MARK: - KeyboardTypeTool

/// Types a text string via CGEvent key events.
/// Verifies the context lock before executing.
/// Invalidates UIStateCache after execution.
struct KeyboardTypeTool: ToolExecutor {

    // MARK: - Dependencies

    let inputService: any InputControlling
    let contextLockChecker: ContextLockChecker
    let cache: UIStateCache
    let postActionDelay: TimeInterval

    // MARK: - Init

    init(inputService: any InputControlling,
         contextLockChecker: ContextLockChecker,
         cache: UIStateCache,
         postActionDelay: TimeInterval = 0.2) {
        self.inputService = inputService
        self.contextLockChecker = contextLockChecker
        self.cache = cache
        self.postActionDelay = postActionDelay
    }

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "keyboard_type",
            description: """
            Types a text string using keyboard events. \
            Call get_ui_state first to set the context lock. \
            Prefer ax_action set_value when a specific field ref is known.
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to type")
                    ])
                ]),
                "required": .array([.string("text")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let text) = arguments["text"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: text", isError: true)
        }
        guard !text.isEmpty else {
            return ToolResult(toolUseId: id, content: "text cannot be empty", isError: true)
        }
        if let lockError = contextLockChecker.verify() {
            return ToolResult(toolUseId: id, content: lockError, isError: true)
        }

        do {
            try await inputService.typeText(text)
            cache.invalidate()
            if postActionDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(postActionDelay * 1_000_000_000))
            }
            Logger.input.info("keyboard_type: typed \(text.count) characters")
            return ToolResult(toolUseId: id, content: "Typed \(text.count) character(s)", isError: false)
        } catch {
            return ToolResult(toolUseId: id,
                              content: "Typing failed: \(error.localizedDescription)",
                              isError: true)
        }
    }
}
