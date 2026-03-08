import Testing
import Foundation
@testable import JARVIS

@Suite("TTSTextSanitizer Tests")
struct TTSTextSanitizerTests {

    // MARK: - Bold / Italic

    @Test("strips **bold** markers")
    func testStripsBold() {
        let result = TTSTextSanitizer.sanitize("This is **bold** text")
        #expect(result == "This is bold text")
    }

    @Test("strips *italic* markers")
    func testStripsItalic() {
        let result = TTSTextSanitizer.sanitize("This is *italic* text")
        #expect(result == "This is italic text")
    }

    @Test("strips ***bold italic*** markers")
    func testStripsBoldItalic() {
        let result = TTSTextSanitizer.sanitize("This is ***bold italic*** text")
        #expect(result == "This is bold italic text")
    }

    @Test("strips __underscore bold__ markers")
    func testStripsUnderscoreBold() {
        let result = TTSTextSanitizer.sanitize("This is __bold__ text")
        #expect(result == "This is bold text")
    }

    @Test("strips ~~strikethrough~~ markers")
    func testStripsStrikethrough() {
        let result = TTSTextSanitizer.sanitize("This is ~~deleted~~ text")
        #expect(result == "This is deleted text")
    }

    // MARK: - Headings

    @Test("strips heading markers")
    func testStripsHeadings() {
        let input = "# Title\n## Subtitle\n### Section"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "Title\nSubtitle\nSection")
    }

    // MARK: - Code

    @Test("strips inline code backticks")
    func testStripsInlineCode() {
        let result = TTSTextSanitizer.sanitize("Use the `print` function")
        #expect(result == "Use the print function")
    }

    @Test("removes fenced code blocks entirely")
    func testRemovesFencedCodeBlocks() {
        let input = "Before\n```swift\nlet x = 1\n```\nAfter"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "Before\n\nAfter")
    }

    // MARK: - LaTeX

    @Test("removes inline LaTeX $...$")
    func testRemovesInlineLatex() {
        let result = TTSTextSanitizer.sanitize("The formula $E = mc^2$ is famous")
        #expect(result == "The formula is famous")
    }

    @Test("removes display LaTeX $$...$$")
    func testRemovesDisplayLatex() {
        let input = "Here:\n$$\\int_0^1 x dx$$\nDone"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "Here:\n\nDone")
    }

    @Test("removes \\(...\\) inline LaTeX")
    func testRemovesParenLatex() {
        let result = TTSTextSanitizer.sanitize("The value \\(x^2\\) is squared")
        #expect(result == "The value is squared")
    }

    @Test("removes \\[...\\] display LaTeX")
    func testRemovesBracketLatex() {
        let input = "Formula:\n\\[x^2 + y^2 = z^2\\]\nEnd"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "Formula:\n\nEnd")
    }

    // MARK: - Links and Images

    @Test("converts links to text only")
    func testConvertsLinks() {
        let result = TTSTextSanitizer.sanitize("Visit [Google](https://google.com) now")
        #expect(result == "Visit Google now")
    }

    @Test("removes images entirely")
    func testRemovesImages() {
        let result = TTSTextSanitizer.sanitize("See ![screenshot](image.png) here")
        #expect(result == "See here")
    }

    // MARK: - Lists

    @Test("strips bullet list markers")
    func testStripsBulletMarkers() {
        let input = "- First item\n- Second item\n* Third item"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "First item\nSecond item\nThird item")
    }

    @Test("strips numbered list markers")
    func testStripsNumberedMarkers() {
        let input = "1. First\n2. Second\n3. Third"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "First\nSecond\nThird")
    }

    // MARK: - Blockquotes

    @Test("strips blockquote markers")
    func testStripsBlockquotes() {
        let result = TTSTextSanitizer.sanitize("> This is quoted text")
        #expect(result == "This is quoted text")
    }

    // MARK: - HTML

    @Test("strips HTML tags")
    func testStripsHTMLTags() {
        let result = TTSTextSanitizer.sanitize("Hello <b>world</b> and <em>more</em>")
        #expect(result == "Hello world and more")
    }

    // MARK: - Horizontal Rules

    @Test("removes horizontal rules")
    func testRemovesHorizontalRules() {
        let input = "Above\n---\nBelow"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result == "Above\n\nBelow")
    }

    // MARK: - Tables

    @Test("removes pipe characters from tables")
    func testRemovesPipes() {
        let input = "| Name | Value |"
        let result = TTSTextSanitizer.sanitize(input)
        #expect(result.contains("|") == false)
        #expect(result.contains("Name"))
        #expect(result.contains("Value"))
    }

    // MARK: - Whitespace Cleanup

    @Test("collapses excess whitespace")
    func testCollapsesWhitespace() {
        let result = TTSTextSanitizer.sanitize("Too   many   spaces")
        #expect(result == "Too many spaces")
    }

    @Test("collapses excessive newlines")
    func testCollapsesNewlines() {
        let result = TTSTextSanitizer.sanitize("Line one\n\n\n\n\nLine two")
        #expect(result == "Line one\n\nLine two")
    }

    // MARK: - Combined / Real-world

    @Test("sanitizes a realistic Claude response")
    func testRealisticResponse() {
        let input = """
        ## Here's what I found:

        The **temperature** is currently *72°F*. Here are the details:

        - Wind: 5 mph
        - Humidity: 45%

        > Source: Weather API

        For the formula $T = (F - 32) \\times 5/9$, you can convert to Celsius.
        """
        let result = TTSTextSanitizer.sanitize(input)
        #expect(!result.contains("**"))
        #expect(!result.contains("*"))
        #expect(!result.contains("##"))
        #expect(!result.contains("$"))
        #expect(!result.contains(">"))
        #expect(result.contains("temperature"))
        #expect(result.contains("72°F"))
    }

    @Test("plain text passes through unchanged")
    func testPlainTextUnchanged() {
        let input = "Hello, how are you doing today?"
        #expect(TTSTextSanitizer.sanitize(input) == input)
    }

    @Test("empty string returns empty")
    func testEmptyString() {
        #expect(TTSTextSanitizer.sanitize("") == "")
    }
}
