import Foundation

// MARK: - AXActionTool

/// Performs an action on a UI element identified by an @e ref.
/// Always invalidates the UIStateCache after executing (regardless of success/failure).
struct AXActionTool: ToolExecutor {

    // MARK: - Dependencies

    let accessibilityService: any AccessibilityServiceProtocol
    let cache: UIStateCache

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "ax_action",
            description: """
            Performs an action on a UI element identified by its ref (e.g. @e3). \
            Always call get_ui_state first to get current refs. \
            Actions: press (click a button), set_value (type into a field), \
            focus (focus an element), show_menu (show contextual menu), raise (bring window to front).
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "ref": .object([
                        "type": .string("string"),
                        "description": .string("Element reference, e.g. @e3")
                    ]),
                    "action": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("press"),
                            .string("set_value"),
                            .string("focus"),
                            .string("show_menu"),
                            .string("raise")
                        ]),
                        "description": .string("The action to perform")
                    ]),
                    "value": .object([
                        "type": .string("string"),
                        "description": .string("Required when action is set_value")
                    ])
                ]),
                "required": .array([.string("ref"), .string("action")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let ref) = arguments["ref"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: ref", isError: true)
        }
        guard case .string(let action) = arguments["action"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: action", isError: true)
        }

        // Always invalidate cache before and after (UI is changing)
        defer { cache.invalidate() }

        do {
            let success: Bool
            switch action {
            case "press":
                success = try await accessibilityService.performAction(ref: ref, action: "AXPress")
            case "show_menu":
                success = try await accessibilityService.performAction(ref: ref, action: "AXShowMenu")
            case "raise":
                success = try await accessibilityService.performAction(ref: ref, action: "AXRaise")
            case "focus":
                success = try await accessibilityService.setFocused(ref: ref)
            case "set_value":
                guard case .string(let value) = arguments["value"] else {
                    return ToolResult(toolUseId: id,
                                      content: "Missing required argument: value (required when action is set_value)",
                                      isError: true)
                }
                success = try await accessibilityService.setValue(ref: ref, attribute: "AXValue", value: value)
            default:
                return ToolResult(toolUseId: id,
                                  content: "Unknown action '\(action)'. Valid actions: press, set_value, focus, show_menu, raise",
                                  isError: true)
            }

            let outcome = success ? "Action '\(action)' on \(ref) succeeded" : "Action '\(action)' on \(ref) returned false"
            Logger.tools.info("ax_action: \(action) on \(ref) → success=\(success)")
            return ToolResult(toolUseId: id, content: outcome, isError: !success)

        } catch AXServiceError.invalidElement {
            return ToolResult(toolUseId: id,
                              content: "Element \(ref) not found. Call get_ui_state to refresh element refs.",
                              isError: true)
        } catch {
            return ToolResult(toolUseId: id, content: "Action failed: \(error.localizedDescription)", isError: true)
        }
    }
}
