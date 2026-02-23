import CoreGraphics
import Foundation

struct WindowListTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "window_list",
            description: "Lists currently visible on-screen windows with app name, title, position, and size",
            inputSchema: .object(["type": .string("object")])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ToolResult(toolUseId: id, content: "No visible windows found", isError: false)
        }

        let lines: [String] = windowList.compactMap { info -> String? in
            // Only normal windows (layer 0)
            guard let layer = info["kCGWindowLayer"] as? Int, layer == 0 else { return nil }

            let appName = info["kCGWindowOwnerName"] as? String ?? "Unknown"
            let title = info["kCGWindowName"] as? String ?? ""
            let windowID = info["kCGWindowNumber"] as? Int ?? 0

            var boundsStr = ""
            if let bounds = info["kCGWindowBounds"] as? [String: Any] {
                let x = Int(bounds["X"] as? CGFloat ?? 0)
                let y = Int(bounds["Y"] as? CGFloat ?? 0)
                let w = Int(bounds["Width"] as? CGFloat ?? 0)
                let h = Int(bounds["Height"] as? CGFloat ?? 0)
                boundsStr = "\(x),\(y) \(w)x\(h)"
            }

            let titlePart = title.isEmpty ? "" : " | \(title)"
            return "[\(windowID)] \(appName)\(titlePart) | \(boundsStr)"
        }

        if lines.isEmpty {
            return ToolResult(toolUseId: id, content: "No visible windows found", isError: false)
        }

        let content = lines.joined(separator: "\n")
        Logger.tools.info("window_list: found \(lines.count) windows")
        return ToolResult(toolUseId: id, content: content, isError: false)
    }
}
