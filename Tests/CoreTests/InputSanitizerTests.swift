import Testing
@testable import JARVIS

@Suite("InputSanitizer Tests")
struct InputSanitizerTests {

    private func toolUse(input: [String: JSONValue]) -> ToolUse {
        ToolUse(id: "test-id", name: "test_tool", input: input)
    }

    // MARK: - 1. Clean Input

    @Test func cleanInputReturnsNoViolations() {
        let call = toolUse(input: ["path": .string("/Users/user/Documents/file.txt")])
        #expect(InputSanitizer.check(call: call).isEmpty)
    }

    // MARK: - 2–5. Path Traversal

    @Test func pathTraversalSlashDetected() {
        let call = toolUse(input: ["path": .string("../secret")])
        let violations = InputSanitizer.check(call: call)
        #expect(!violations.isEmpty)
        #expect(violations.contains {
            if case .pathTraversal(let field, _) = $0 { return field == "path" }
            return false
        })
    }

    @Test func pathTraversalMidPathDetected() {
        let call = toolUse(input: ["path": .string("/some/path/../etc/passwd")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .pathTraversal = $0 { return true }; return false })
    }

    @Test func pathTraversalWindowsBackslashDetected() {
        let call = toolUse(input: ["path": .string("..\\Windows\\System32")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .pathTraversal = $0 { return true }; return false })
    }

    @Test func dotDotAloneIsNotPathTraversal() {
        let call = toolUse(input: ["name": .string("..")])
        let violations = InputSanitizer.check(call: call)
        let traversalViolations = violations.filter { if case .pathTraversal = $0 { return true }; return false }
        #expect(traversalViolations.isEmpty)
    }

    // MARK: - 6–12. System Paths

    @Test func systemPathSystemBlocked() {
        let call = toolUse(input: ["path": .string("/System/Library/Frameworks")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathLibraryBlocked() {
        let call = toolUse(input: ["path": .string("/Library/Preferences")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathUsrBlocked() {
        let call = toolUse(input: ["path": .string("/usr/local/bin")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathBinBlocked() {
        let call = toolUse(input: ["path": .string("/bin/sh")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathSbinBlocked() {
        let call = toolUse(input: ["path": .string("/sbin/launchd")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathPrivateBlocked() {
        let call = toolUse(input: ["path": .string("/private/etc/hosts")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    @Test func systemPathCheckIsCaseInsensitive() {
        let call = toolUse(input: ["path": .string("/SYSTEM/Library")])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains { if case .systemPath = $0 { return true }; return false })
    }

    // MARK: - 13–14. Control Characters

    @Test func controlCharactersDetected() {
        let withNull = toolUse(input: ["text": .string("hello\u{0000}world")])
        let withEsc = toolUse(input: ["text": .string("hello\u{001B}world")])
        #expect(InputSanitizer.check(call: withNull).contains {
            if case .controlCharacters(let field) = $0 { return field == "text" }
            return false
        })
        #expect(InputSanitizer.check(call: withEsc).contains {
            if case .controlCharacters = $0 { return true }
            return false
        })
    }

    @Test func allowedWhitespaceNotFlagged() {
        let call = toolUse(input: ["text": .string("line one\nline two\r\nwith\ttab")])
        let controlViolations = InputSanitizer.check(call: call).filter {
            if case .controlCharacters = $0 { return true }
            return false
        }
        #expect(controlViolations.isEmpty)
    }

    // MARK: - 15–16. Length Limits

    @Test func lengthLimitExceededFlagged() {
        let longString = String(repeating: "a", count: 10_001)
        let call = toolUse(input: ["text": .string(longString)])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.contains {
            if case .lengthExceeded(let field, let limit, let actual) = $0 {
                return field == "text" && limit == 10_000 && actual == 10_001
            }
            return false
        })
    }

    @Test func exactLengthLimitNotExceeded() {
        let exactString = String(repeating: "a", count: 10_000)
        let call = toolUse(input: ["text": .string(exactString)])
        let lengthViolations = InputSanitizer.check(call: call).filter {
            if case .lengthExceeded = $0 { return true }
            return false
        }
        #expect(lengthViolations.isEmpty)
    }

    // MARK: - 17. Nested Values

    @Test func nestedStringValuesInObjectAndArrayAreChecked() {
        let call = toolUse(input: [
            "options": .object(["path": .string("../secret")]),
            "paths": .array([.string("/System/Library")])
        ])
        let violations = InputSanitizer.check(call: call)
        #expect(violations.count >= 2)
    }
}
