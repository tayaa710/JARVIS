import Foundation
import CoreGraphics

// MARK: - MouseMoveTool

/// Moves the mouse cursor to specific screen coordinates via CGEvent.
/// No context lock check — cursor repositioning is harmless.
/// No cache invalidation — cursor movement alone does not change UI state.
struct MouseMoveTool: ToolExecutor {

    // MARK: - Dependencies

    let inputService: any InputControlling
    let postActionDelay: TimeInterval

    // MARK: - Init

    init(inputService: any InputControlling, postActionDelay: TimeInterval = 0.2) {
        self.inputService = inputService
        self.postActionDelay = postActionDelay
    }

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "mouse_move",
            description: """
            Moves the mouse cursor to specific screen coordinates. \
            Coordinates are in screen points (origin at top-left). \
            Does not click — use mouse_click to click.
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
                    ])
                ]),
                "required": .array([.string("x"), .string("y")])
            ])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .number(let x) = arguments["x"],
              case .number(let y) = arguments["y"] else {
            return ToolResult(toolUseId: id,
                              content: "Missing required arguments: x and y (screen coordinates)",
                              isError: true)
        }

        let position = CGPoint(x: x, y: y)
        do {
            try await inputService.mouseMove(to: position)
            if postActionDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(postActionDelay * 1_000_000_000))
            }
            Logger.input.info("mouse_move: moved to (\(Int(x)), \(Int(y)))")
            return ToolResult(toolUseId: id,
                              content: "Moved mouse to (\(Int(x)), \(Int(y)))",
                              isError: false)
        } catch {
            return ToolResult(toolUseId: id,
                              content: "Mouse move failed: \(error.localizedDescription)",
                              isError: true)
        }
    }
}
