import AppKit

struct AppListTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "app_list",
            description: "Returns a list of currently running applications with their name, bundle ID, and process ID",
            inputSchema: .object(["type": .string("object")])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.isActive || $0.activationPolicy == .regular }
            .compactMap { app -> String? in
                guard let name = app.localizedName else { return nil }
                let bundle = app.bundleIdentifier ?? "unknown"
                return "\(name) (\(bundle)) PID=\(app.processIdentifier)"
            }

        let content: String
        if apps.isEmpty {
            content = "No applications are currently running"
        } else {
            content = apps.joined(separator: "\n")
        }

        Logger.tools.info("app_list executed, found \(apps.count) apps")
        return ToolResult(toolUseId: id, content: content, isError: false)
    }
}
