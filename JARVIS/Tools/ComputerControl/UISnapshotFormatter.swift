import Foundation

// MARK: - UISnapshotFormatter

/// Converts a UITreeSnapshot into a compact, human-readable text format
/// that Claude can parse to understand the current UI state.
enum UISnapshotFormatter {

    /// Formats a UITreeSnapshot as indented text. Example output:
    /// ```
    /// App: Safari (com.apple.Safari)
    /// @e1 AXWindow "My Page"
    ///   @e2 AXToolbar
    ///     @e3 AXButton "Back" [enabled]
    /// (3 elements)
    /// ```
    static func format(_ snapshot: UITreeSnapshot) -> String {
        var lines: [String] = []
        lines.append("App: \(snapshot.appName) (\(snapshot.bundleId))")
        formatElement(snapshot.root, depth: 0, lines: &lines)
        if snapshot.truncated {
            lines.append("(\(snapshot.elementCount) elements, truncated)")
        } else {
            lines.append("(\(snapshot.elementCount) elements)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private static func formatElement(
        _ element: UIElementSnapshot,
        depth: Int,
        lines: inout [String]
    ) {
        let indent = String(repeating: "  ", count: depth)
        var parts: [String] = [indent + element.ref, element.role]

        if let title = element.title, !title.isEmpty {
            parts.append("\"\(title)\"")
        }

        if let value = element.value, !value.isEmpty {
            let truncated = value.count > 80 ? String(value.prefix(80)) + "…" : value
            parts.append("value=\"\(truncated)\"")
        }

        if !element.isEnabled {
            parts.append("[disabled]")
        }

        lines.append(parts.joined(separator: " "))

        for child in element.children {
            formatElement(child, depth: depth + 1, lines: &lines)
        }
    }
}
