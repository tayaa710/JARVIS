import Foundation

// MARK: - GetUIStateTool

/// Returns a formatted text snapshot of the frontmost app's AX tree.
/// Results are cached for 0.5 seconds (configurable via UIStateCache).
/// Sets the context lock after each fresh walk.
final class GetUIStateTool: ToolExecutor, @unchecked Sendable {

    // MARK: - Dependencies

    private let accessibilityService: any AccessibilityServiceProtocol
    private let cache: UIStateCache

    /// Called after each fresh walk to record the current context lock.
    var contextLockSetter: (@Sendable (ContextLock) -> Void)?

    // MARK: - Init

    init(accessibilityService: any AccessibilityServiceProtocol, cache: UIStateCache) {
        self.accessibilityService = accessibilityService
        self.cache = cache
    }

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "get_ui_state",
            description: """
            Returns a formatted text snapshot of the frontmost application's UI accessibility tree. \
            Each element is assigned a reference (@e1, @e2, etc.) that can be used with ax_action. \
            Use this before interacting with any UI element.
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "max_depth": .object([
                        "type": .string("integer"),
                        "description": .string("Maximum depth to traverse (default: 5)")
                    ]),
                    "max_elements": .object([
                        "type": .string("integer"),
                        "description": .string("Maximum number of elements to capture (default: 300)")
                    ])
                ])
            ])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        // Check cache first
        if let cached = cache.get() {
            Logger.tools.info("get_ui_state: returning cached result")
            return ToolResult(toolUseId: id, content: cached.result, isError: false)
        }

        // Parse optional arguments
        let maxDepth: Int
        if case .number(let d) = arguments["max_depth"] { maxDepth = Int(d) } else { maxDepth = 5 }
        let maxElements: Int
        if case .number(let e) = arguments["max_elements"] { maxElements = Int(e) } else { maxElements = 300 }

        // Walk the tree
        do {
            let snapshot = try await accessibilityService.walkFrontmostApp(
                maxDepth: maxDepth,
                maxElements: maxElements
            )
            let formatted = UISnapshotFormatter.format(snapshot)
            cache.set(result: formatted, snapshot: snapshot)

            // Set context lock
            let lock = ContextLock(bundleId: snapshot.bundleId, pid: snapshot.pid)
            contextLockSetter?(lock)

            Logger.tools.info("get_ui_state: walked \(snapshot.elementCount) elements for \(snapshot.appName)")
            return ToolResult(toolUseId: id, content: formatted, isError: false)
        } catch AXServiceError.noFrontmostApp {
            return ToolResult(toolUseId: id, content: "No frontmost application found", isError: true)
        } catch AXServiceError.permissionDenied {
            return ToolResult(toolUseId: id, content: "Accessibility permission denied. Grant access in System Settings → Privacy & Security → Accessibility.", isError: true)
        } catch {
            return ToolResult(toolUseId: id, content: "Failed to get UI state: \(error.localizedDescription)", isError: true)
        }
    }
}
