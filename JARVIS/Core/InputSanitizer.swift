import Foundation

// MARK: - SanitizationViolation

enum SanitizationViolation {
    case pathTraversal(field: String, value: String)
    case systemPath(field: String, value: String)
    case controlCharacters(field: String)
    case lengthExceeded(field: String, limit: Int, actual: Int)
}

// MARK: - InputSanitizer

enum InputSanitizer {

    static let lengthLimit = 10_000

    private static let systemPathPrefixes = [
        "/system/", "/library/", "/usr/", "/bin/", "/sbin/", "/private/"
    ]

    /// Check all string values in a tool call's input for sanitization violations.
    /// Returns an empty array if the input is clean.
    static func check(call: ToolUse) -> [SanitizationViolation] {
        var violations: [SanitizationViolation] = []
        for (key, value) in call.input {
            violations.append(contentsOf: checkValue(value, field: key))
        }
        return violations
    }

    // MARK: - Private

    private static func checkValue(_ value: JSONValue, field: String) -> [SanitizationViolation] {
        var violations: [SanitizationViolation] = []
        switch value {
        case .string(let str):
            violations.append(contentsOf: checkString(str, field: field))
        case .object(let dict):
            for (key, val) in dict {
                violations.append(contentsOf: checkValue(val, field: "\(field).\(key)"))
            }
        case .array(let arr):
            for (index, val) in arr.enumerated() {
                violations.append(contentsOf: checkValue(val, field: "\(field)[\(index)]"))
            }
        default:
            break
        }
        return violations
    }

    private static func checkString(_ str: String, field: String) -> [SanitizationViolation] {
        var violations: [SanitizationViolation] = []

        // Length check
        if str.count > lengthLimit {
            violations.append(.lengthExceeded(field: field, limit: lengthLimit, actual: str.count))
        }

        // Control character check (ASCII 0–31 except \t=9, \n=10, \r=13)
        let hasControlChar = str.unicodeScalars.contains { scalar in
            let v = scalar.value
            return v < 32 && v != 9 && v != 10 && v != 13
        }
        if hasControlChar {
            violations.append(.controlCharacters(field: field))
        }

        // Path traversal check
        if str.contains("../") || str.contains("..\\") {
            violations.append(.pathTraversal(field: field, value: str))
        }

        // System path check (case-insensitive)
        let lower = str.lowercased()
        if systemPathPrefixes.contains(where: { lower.hasPrefix($0) }) {
            violations.append(.systemPath(field: field, value: str))
        }

        return violations
    }
}
