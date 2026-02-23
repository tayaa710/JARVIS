import Foundation
import Darwin

struct FileSearchTool: ToolExecutor {

    private static let maxResults = 100
    private static let maxDepth = 10

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "file_search",
            description: "Searches for files by name or glob pattern within a directory. Returns up to 100 matching file paths.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Filename or glob pattern to search for (e.g. \"*.txt\", \"notes.md\")")
                    ]),
                    "directory": .object([
                        "type": .string("string"),
                        "description": .string("Directory to search in. Defaults to the user's home directory.")
                    ])
                ]),
                "required": .array([.string("query")])
            ])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard case .string(let query) = arguments["query"] else {
            return ToolResult(toolUseId: id, content: "Missing required argument: query", isError: true)
        }

        let searchDir: String
        if case .string(let dir) = arguments["directory"] {
            searchDir = dir
        } else {
            searchDir = NSHomeDirectory()
        }

        let searchURL = URL(fileURLWithPath: searchDir)
        var results: [String] = []
        var limited = false

        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let enumerator = FileManager.default.enumerator(
            at: searchURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else {
            return ToolResult(toolUseId: id, content: "Could not enumerate directory: \(searchDir)", isError: true)
        }

        for case let fileURL as URL in enumerator {
            // Enforce depth limit
            let depth = fileURL.pathComponents.count - searchURL.pathComponents.count
            if depth > Self.maxDepth {
                enumerator.skipDescendants()
                continue
            }

            // Check if it's a file
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            let fileName = fileURL.lastPathComponent
            if matchesQuery(query, filename: fileName) {
                results.append(fileURL.path)
                if results.count >= Self.maxResults {
                    limited = true
                    break
                }
            }
        }

        if results.isEmpty {
            let content = "No files found matching \"\(query)\" in \(searchDir)"
            Logger.tools.info("file_search: no results for query=\(query)")
            return ToolResult(toolUseId: id, content: content, isError: false)
        }

        var content = results.joined(separator: "\n")
        if limited {
            content += "\n\n(\(Self.maxResults) results limited — there may be more matches)"
        }

        Logger.tools.info("file_search: found \(results.count) results for query=\(query)")
        return ToolResult(toolUseId: id, content: content, isError: false)
    }

    // MARK: - Private

    private func matchesQuery(_ query: String, filename: String) -> Bool {
        // Use fnmatch for glob pattern matching (case-insensitive via lowercasing)
        let lowQuery = query.lowercased()
        let lowName = filename.lowercased()
        return fnmatch(lowQuery, lowName, 0) == 0
    }
}
