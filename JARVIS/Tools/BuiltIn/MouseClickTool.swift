import Foundation
import CoreGraphics

// MARK: - MouseClickTool

/// Performs a mouse click at specific screen coordinates via CGEvent.
/// Verifies the context lock before executing.
/// Invalidates UIStateCache after execution.
struct MouseClickTool: ToolExecutor {

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
            name: "mouse_click",
            description: """
            Clicks at specific screen coordinates. \
            Use ax_action press when a UI element ref is available — it's more reliable. \
            Call get_ui_state first to set the context lock. \
            Coordinates are in screen points (origin at top-left).
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("Horizontal position in screen points")
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Vertical position in screen points")
                    ]),
                    "button": .object([
                        "type": .string("string"),
                        "enum": .array([.string("left"), .string("right")]),
                        "description": .string("Mouse button (default: left)")
                    ]),
                    "click_count": .object([
                        "type": .string("integer"),
                        "description": .string("Number of clicks (1 = single, 2 = double, default: 1)")
                    ])
                ]),
                "required": .array([.string("x"), .string("y")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .number(let x) = arguments["x"],
              case .number(let y) = arguments["y"] else {
            return ToolResult(toolUseId: id,
                              content: "Missing required arguments: x and y (screen coordinates)",
                              isError: true)
        }

        let buttonStr: String
        if case .string(let s) = arguments["button"] { buttonStr = s } else { buttonStr = "left" }

        let clickCount: Int
        if case .number(let n) = arguments["click_count"] { clickCount = Int(n) } else { clickCount = 1 }

        let button: CGMouseButton
        switch buttonStr {
        case "left":  button = .left
        case "right": button = .right
        default:
            return ToolResult(toolUseId: id,
                              content: "Invalid button '\(buttonStr)'. Valid values: left, right",
                              isError: true)
        }

        if let lockError = contextLockChecker.verify() {
            return ToolResult(toolUseId: id, content: lockError, isError: true)
        }

        let position = CGPoint(x: x, y: y)
        do {
            try await inputService.mouseClick(position: position, button: button, clickCount: clickCount)
            cache.invalidate()
            if postActionDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(postActionDelay * 1_000_000_000))
            }
            Logger.input.info("mouse_click: \(buttonStr) click ×\(clickCount) at (\(Int(x)), \(Int(y)))")
            return ToolResult(toolUseId: id,
                              content: "Clicked at (\(Int(x)), \(Int(y)))",
                              isError: false)
        } catch {
            return ToolResult(toolUseId: id,
                              content: "Click failed: \(error.localizedDescription)",
                              isError: true)
        }
    }
}
