import AppKit

struct AppOpenTool: ToolExecutor {

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "app_open",
            description: "Opens or activates an application by name. If already running, brings it to the front.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application to open (e.g. \"Safari\", \"Finder\", \"Calculator\")")
                    ])
                ]),
                "required": .array([.string("name")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let name) = arguments["name"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: name", isError: true)
        }

        guard !name.isEmpty else {
            return ToolResult(toolUseId: id, content: "App name cannot be empty", isError: true)
        }

        // Check if the app is already running
        let running = NSWorkspace.shared.runningApplications.first {
            $0.localizedName?.lowercased() == name.lowercased()
        }

        if let app = running {
            app.activate(options: [.activateIgnoringOtherApps])
            Logger.tools.info("app_open: activated already-running app '\(name)'")
            return ToolResult(
                toolUseId: id,
                content: "\(app.localizedName ?? name) is already running, brought to front",
                isError: false
            )
        }

        // Launch via /usr/bin/open -a — uses argument array to avoid shell injection
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ToolResult(
                toolUseId: id,
                content: "Failed to launch \(name): \(error.localizedDescription)",
                isError: true
            )
        }

        if process.terminationStatus == 0 {
            Logger.tools.info("app_open: launched '\(name)'")
            return ToolResult(toolUseId: id, content: "Launched \(name) successfully", isError: false)
        } else {
            return ToolResult(
                toolUseId: id,
                content: "Could not open application \"\(name)\". Check that the app name is correct.",
                isError: true
            )
        }
    }
}
