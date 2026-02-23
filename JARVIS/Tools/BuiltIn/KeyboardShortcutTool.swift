import Foundation

// MARK: - KeyboardShortcutTool

/// Presses a key combination such as Cmd+C or Ctrl+Shift+A via CGEvent.
/// Verifies the context lock before executing.
/// Invalidates UIStateCache after execution.
struct KeyboardShortcutTool: ToolExecutor {

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
            name: "keyboard_shortcut",
            description: """
            Presses a keyboard shortcut (e.g. "cmd+c", "ctrl+shift+a"). \
            Modifiers: cmd, shift, alt/option, ctrl. Keys: letters, numbers, \
            return, tab, space, escape, arrows (up/down/left/right), f1-f12. \
            Call get_ui_state first to set the context lock.
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "shortcut": .object([
                        "type": .string("string"),
                        "description": .string("Key combo, e.g. \"cmd+c\", \"ctrl+shift+a\"")
                    ])
                ]),
                "required": .array([.string("shortcut")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let shortcut) = arguments["shortcut"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: shortcut", isError: true)
        }
        guard !shortcut.isEmpty else {
            return ToolResult(toolUseId: id, content: "shortcut cannot be empty", isError: true)
        }
        guard let (modifiers, keyCode) = KeyCodeMap.parseCombo(shortcut) else {
            return ToolResult(toolUseId: id,
                              content: "Invalid shortcut '\(shortcut)'. Format: 'cmd+c', 'ctrl+shift+a'. " +
                                       "Supported modifiers: cmd, shift, alt, ctrl.",
                              isError: true)
        }
        if let lockError = contextLockChecker.verify() {
            return ToolResult(toolUseId: id, content: lockError, isError: true)
        }

        do {
            try await inputService.pressShortcut(modifiers: modifiers, keyCode: keyCode)
            cache.invalidate()
            if postActionDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(postActionDelay * 1_000_000_000))
            }
            Logger.input.info("keyboard_shortcut: sent '\(shortcut)'")
            return ToolResult(toolUseId: id, content: "Shortcut '\(shortcut)' sent", isError: false)
        } catch {
            return ToolResult(toolUseId: id,
                              content: "Shortcut failed: \(error.localizedDescription)",
                              isError: true)
        }
    }
}
