import Foundation

// MARK: - AXFindTool

/// Searches the current UI tree for elements matching role, title, and/or value criteria.
/// Uses the cached snapshot from UIStateCache if available; otherwise walks fresh.
struct AXFindTool: ToolExecutor {

    // MARK: - Dependencies

    let accessibilityService: any AccessibilityServiceProtocol
    let cache: UIStateCache

    // MARK: - ToolExecutor

    var definition: ToolDefinition {
        ToolDefinition(
            name: "ax_find",
            description: """
            Searches the frontmost app's UI tree for elements matching the given criteria. \
            At least one of role, title, or value must be provided. \
            Matching is case-insensitive substring matching. \
            Returns a list of matching elements with their refs for use with ax_action.
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("AX role to match, e.g. AXButton, AXTextField")
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Substring to match against element title (case-insensitive)")
                    ]),
                    "value": .object([
                        "type": .string("string"),
                        "description": .string("Substring to match against element value (case-insensitive)")
                    ])
                ])
            ])
        )
    }

    var riskLevel: RiskLevel { .safe }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        let roleFilter: String?
        let titleFilter: String?
        let valueFilter: String?

        if case .string(let r) = arguments["role"] { roleFilter = r } else { roleFilter = nil }
        if case .string(let t) = arguments["title"] { titleFilter = t } else { titleFilter = nil }
        if case .string(let v) = arguments["value"] { valueFilter = v } else { valueFilter = nil }

        guard roleFilter != nil || titleFilter != nil || valueFilter != nil else {
            return ToolResult(toolUseId: id,
                              content: "At least one filter (role, title, or value) is required",
                              isError: true)
        }

        // Get snapshot from cache or walk fresh
        let snapshot: UITreeSnapshot
        if let cached = cache.get() {
            snapshot = cached.snapshot
        } else {
            do {
                snapshot = try await accessibilityService.walkFrontmostApp(maxDepth: 5, maxElements: 300)
                let formatted = UISnapshotFormatter.format(snapshot)
                cache.set(result: formatted, snapshot: snapshot)
            } catch AXServiceError.noFrontmostApp {
                return ToolResult(toolUseId: id, content: "No frontmost application found", isError: true)
            } catch {
                return ToolResult(toolUseId: id, content: "Failed to read UI state: \(error.localizedDescription)", isError: true)
            }
        }

        // Search recursively
        var matches: [UIElementSnapshot] = []
        searchElement(snapshot.root,
                      roleFilter: roleFilter?.lowercased(),
                      titleFilter: titleFilter?.lowercased(),
                      valueFilter: valueFilter?.lowercased(),
                      matches: &matches)

        if matches.isEmpty {
            return ToolResult(toolUseId: id, content: "No elements found matching criteria", isError: false)
        }

        let lines = matches.map { element -> String in
            var parts = ["\(element.ref) \(element.role)"]
            if let title = element.title { parts.append("\"\(title)\"") }
            if let value = element.value { parts.append("value=\"\(value)\"") }
            if !element.isEnabled { parts.append("[disabled]") }
            return parts.joined(separator: " ")
        }

        Logger.tools.info("ax_find: found \(matches.count) matches")
        return ToolResult(toolUseId: id, content: lines.joined(separator: "\n"), isError: false)
    }

    // MARK: - Private Search

    private func searchElement(
        _ element: UIElementSnapshot,
        roleFilter: String?,
        titleFilter: String?,
        valueFilter: String?,
        matches: inout [UIElementSnapshot]
    ) {
        if matchesFilters(element, roleFilter: roleFilter, titleFilter: titleFilter, valueFilter: valueFilter) {
            matches.append(element)
        }
        for child in element.children {
            searchElement(child, roleFilter: roleFilter, titleFilter: titleFilter,
                          valueFilter: valueFilter, matches: &matches)
        }
    }

    private func matchesFilters(
        _ element: UIElementSnapshot,
        roleFilter: String?,
        titleFilter: String?,
        valueFilter: String?
    ) -> Bool {
        if let role = roleFilter, !element.role.lowercased().contains(role) { return false }
        if let title = titleFilter {
            guard let elementTitle = element.title, elementTitle.lowercased().contains(title) else { return false }
        }
        if let value = valueFilter {
            guard let elementValue = element.value, elementValue.lowercased().contains(value) else { return false }
        }
        return true
    }
}
