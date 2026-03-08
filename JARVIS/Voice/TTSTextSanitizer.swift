import Foundation

// MARK: - TTSTextSanitizer

/// Strips markdown, LaTeX, code blocks, and other formatting from text
/// so that TTS engines speak natural language instead of raw markup.
public enum TTSTextSanitizer {

    /// Sanitize text for TTS consumption.
    /// Removes markdown formatting, LaTeX, code blocks, HTML tags, etc.
    public static func sanitize(_ text: String) -> String {
        var result = text

        // 1. Remove fenced code blocks (```...```) entirely
        result = result.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: "",
            options: .regularExpression
        )

        // 2. Remove inline code (`...`)
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "$1",
            options: .regularExpression
        )

        // 3. Remove LaTeX display math ($$...$$) and (\[...\])
        result = result.replacingOccurrences(
            of: "\\$\\$[\\s\\S]*?\\$\\$",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\\\\\[[\\s\\S]*?\\\\\\]",
            with: "",
            options: .regularExpression
        )

        // 4. Remove LaTeX inline math ($...$) and (\(...\))
        result = result.replacingOccurrences(
            of: "\\$([^$]+)\\$",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\\\\\([^)]*\\\\\\)",
            with: "",
            options: .regularExpression
        )

        // 5. Remove images ![alt](url)
        result = result.replacingOccurrences(
            of: "!\\[[^\\]]*\\]\\([^)]*\\)",
            with: "",
            options: .regularExpression
        )

        // 6. Convert links [text](url) → text
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]*\\)",
            with: "$1",
            options: .regularExpression
        )

        // 7. Remove bold/italic markers: ***text*** → text, **text** → text, *text* → text
        // Also handles underscores: ___text___ → text, __text__ → text, _text_ → text
        result = result.replacingOccurrences(
            of: "\\*{1,3}([^*]+)\\*{1,3}",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "_{1,3}([^_]+)_{1,3}",
            with: "$1",
            options: .regularExpression
        )

        // 8. Remove strikethrough ~~text~~ → text
        result = result.replacingOccurrences(
            of: "~~([^~]+)~~",
            with: "$1",
            options: .regularExpression
        )

        // 9. Remove heading markers (# ## ### etc.)
        result = result.replacingOccurrences(
            of: "(?m)^#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )

        // 10. Remove blockquotes (> at start of line)
        result = result.replacingOccurrences(
            of: "(?m)^>\\s*",
            with: "",
            options: .regularExpression
        )

        // 11. Remove horizontal rules (---, ***, ___)
        result = result.replacingOccurrences(
            of: "(?m)^[-*_]{3,}\\s*$",
            with: "",
            options: .regularExpression
        )

        // 12. Remove list markers (-, *, +, 1., 2., etc.) at line start
        result = result.replacingOccurrences(
            of: "(?m)^\\s*[-*+]\\s+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(?m)^\\s*\\d+\\.\\s+",
            with: "",
            options: .regularExpression
        )

        // 13. Remove HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // 14. Remove table formatting pipes
        result = result.replacingOccurrences(
            of: "\\|",
            with: " ",
            options: .regularExpression
        )

        // 15. Clean up excess whitespace
        // Collapse multiple spaces
        result = result.replacingOccurrences(
            of: " {2,}",
            with: " ",
            options: .regularExpression
        )
        // Collapse multiple newlines
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
