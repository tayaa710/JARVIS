import Foundation

struct FileWriteTool: ToolExecutor {

    private static let blockedPrefixes = [
        "/system/", "/library/", "/usr/", "/bin/", "/sbin/", "/private/"
    ]

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "file_write",
            description: "Writes text content to a file at the given absolute path. Creates parent directories if needed. Overwrites existing files.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "path": .object([
                        "type": .string("string"),
                        "description": .string("Absolute path where the file should be written")
                    ]),
                    "content": .object([
                        "type": .string("string"),
                        "description": .string("Text content to write to the file")
                    ])
                ]),
                "required": .array([.string("path"), .string("content")])
            ])
        )
    }

    var riskLevel: RiskLevel { .caution }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let path) = arguments["path"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: path", isError: true)
        }

        guard case .string(let content) = arguments["content"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: content", isError: true)
        }

        if let violation = validatePath(path) {
            return ToolResult(toolUseId: id, content: violation, isError: true)
        }

        let url = URL(fileURLWithPath: path)
        let parentURL = url.deletingLastPathComponent()

        // Create parent directories if needed
        do {
            try FileManager.default.createDirectory(
                at: parentURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            return ToolResult(
                toolUseId: id,
                content: "Failed to create parent directories: \(error.localizedDescription)",
                isError: true
            )
        }

        // Write atomically
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            return ToolResult(
                toolUseId: id,
                content: "Failed to write file: \(error.localizedDescription)",
                isError: true
            )
        }

        let byteCount = content.utf8.count
        Logger.tools.info("file_write: wrote \(byteCount) bytes to \(path)")
        return ToolResult(toolUseId: id, content: "Wrote \(byteCount) bytes to \(path)", isError: false)
    }

    // MARK: - Private

    private func validatePath(_ path: String) -> String? {
        // Must be absolute
        guard path.hasPrefix("/") else {
            return "Path must be absolute (start with /): \(path)"
        }

        // No path traversal
        if path.contains("../") || path.contains("/..") {
            return "Path traversal is not allowed: \(path)"
        }

        // Block system paths (case-insensitive)
        let lowPath = path.lowercased()
        for prefix in Self.blockedPrefixes {
            if lowPath.hasPrefix(prefix) {
                return "Access to system path is not allowed: \(path)"
            }
        }

        return nil
    }
}
