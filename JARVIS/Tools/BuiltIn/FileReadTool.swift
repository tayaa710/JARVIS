import Foundation

struct FileReadTool: ToolExecutor {

    private static let maxBytes = 1_048_576 // 1 MB
    private static let blockedPrefixes = [
        "/system/", "/library/", "/usr/", "/bin/", "/sbin/", "/private/"
    ]

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "file_read",
            description: "Reads the contents of a file at the given absolute path. Files larger than 1 MB are rejected.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "path": .object([
                        "type": .string("string"),
                        "description": .string("Absolute path to the file to read")
                    ])
                ]),
                "required": .array([.string("path")])
            ])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let path) = arguments["path"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: path", isError: true)
        }

        if let violation = validatePath(path) {
            return ToolResult(toolUseId: id, content: violation, isError: true)
        }

        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            return ToolResult(toolUseId: id, content: "File not found: \(path)", isError: true)
        }

        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            return ToolResult(toolUseId: id, content: "Cannot read file attributes: \(error.localizedDescription)", isError: true)
        }

        if let size = attrs[.size] as? Int, size > Self.maxBytes {
            let sizeMB = String(format: "%.1f", Double(size) / 1_048_576)
            return ToolResult(
                toolUseId: id,
                content: "File size \(sizeMB) MB exceeds the 1 MB limit. Use a different tool for large files.",
                isError: true
            )
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            Logger.tools.info("file_read: read \(path)")
            return ToolResult(toolUseId: id, content: content, isError: false)
        } catch {
            return ToolResult(toolUseId: id, content: "Failed to read file: \(error.localizedDescription)", isError: true)
        }
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
