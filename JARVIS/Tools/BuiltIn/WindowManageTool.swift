import AppKit

struct WindowManageTool: ToolExecutor {

    private static let validActions = ["move", "resize", "minimize", "close"]

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "window_manage",
            description: "Moves, resizes, minimizes, or closes a window of the specified application",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "action": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("move"),
                            .string("resize"),
                            .string("minimize"),
                            .string("close")
                        ]),
                        "description": .string("The window action to perform")
                    ]),
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application whose window to manage")
                    ]),
                    "window_number": .object([
                        "type": .string("integer"),
                        "description": .string("Window number (1-based, default 1)")
                    ]),
                    "x": .object([
                        "type": .string("integer"),
                        "description": .string("X position in pixels (required for move)")
                    ]),
                    "y": .object([
                        "type": .string("integer"),
                        "description": .string("Y position in pixels (required for move)")
                    ]),
                    "width": .object([
                        "type": .string("integer"),
                        "description": .string("Width in pixels (required for resize)")
                    ]),
                    "height": .object([
                        "type": .string("integer"),
                        "description": .string("Height in pixels (required for resize)")
                    ])
                ]),
                "required": .array([.string("action"), .string("app_name")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let action) = arguments["action"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: action", isError: true)
        }

        guard Self.validActions.contains(action) else {
            return ToolResult(
                toolUseId: id,
                content: "Invalid action \"\(action)\". Must be one of: \(Self.validActions.joined(separator: ", "))",
                isError: true
            )
        }

        guard case .string(let appName) = arguments["app_name"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: app_name", isError: true)
        }

        let windowNum: Int
        if case .number(let n) = arguments["window_number"] {
            windowNum = Int(n)
        } else {
            windowNum = 1
        }

        let script: String
        switch action {
        case "move":
            guard case .number(let x) = arguments["x"] else {
                return ToolResult(toolUseId: id, content: "Missing required argument for move: x", isError: true)
            }
            guard case .number(let y) = arguments["y"] else {
                return ToolResult(toolUseId: id, content: "Missing required argument for move: y", isError: true)
            }
            let safeApp = sanitizeAppleScriptString(appName)
            script = """
            tell application "System Events"
                tell process "\(safeApp)"
                    set position of window \(windowNum) to {\(Int(x)), \(Int(y))}
                end tell
            end tell
            """

        case "resize":
            guard case .number(let w) = arguments["width"] else {
                return ToolResult(toolUseId: id, content: "Missing required argument for resize: width", isError: true)
            }
            guard case .number(let h) = arguments["height"] else {
                return ToolResult(toolUseId: id, content: "Missing required argument for resize: height", isError: true)
            }
            let safeApp = sanitizeAppleScriptString(appName)
            script = """
            tell application "System Events"
                tell process "\(safeApp)"
                    set size of window \(windowNum) to {\(Int(w)), \(Int(h))}
                end tell
            end tell
            """

        case "minimize":
            let safeApp = sanitizeAppleScriptString(appName)
            script = """
            tell application "\(safeApp)"
                set miniaturized of window \(windowNum) to true
            end tell
            """

        case "close":
            let safeApp = sanitizeAppleScriptString(appName)
            script = """
            tell application "\(safeApp)"
                close window \(windowNum)
            end tell
            """

        default:
            return ToolResult(toolUseId: id, content: "Unknown action: \(action)", isError: true)
        }

        return await runAppleScript(script, id: id, appName: appName, action: action)
    }

    // MARK: - Private

    @MainActor
    private func runAppleScript(
        _ script: String,
        id: String,
        appName: String,
        action: String
    ) -> ToolResult {
        var errorInfo: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let error = errorInfo {
            let message = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown AppleScript error"
            Logger.tools.error("window_manage: AppleScript failed for \(action) on '\(appName)': \(message)")
            return ToolResult(toolUseId: id, content: "AppleScript error: \(message)", isError: true)
        }

        Logger.tools.info("window_manage: \(action) on '\(appName)' succeeded")
        return ToolResult(
            toolUseId: id,
            content: "Successfully performed \(action) on \(appName) window \(result?.stringValue ?? "")",
            isError: false
        )
    }

    private func sanitizeAppleScriptString(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
