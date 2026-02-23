import Foundation

// TestFixtures loads test data from Tests/Fixtures/ using the compile-time #file path.
// This avoids bundle resource configuration — files are read directly from disk.
enum TestFixtures {

    private static var fixturesDirectory: URL {
        // #file is the path to this source file: Tests/Helpers/TestFixtures.swift
        // Navigate up two levels to Tests/, then into Fixtures/.
        let thisFile = URL(fileURLWithPath: #file)
        return thisFile
            .deletingLastPathComponent()  // Helpers/
            .deletingLastPathComponent()  // Tests/
            .appendingPathComponent("Fixtures")
    }

    static func load(_ filename: String) throws -> Data {
        let url = fixturesDirectory.appendingPathComponent(filename)
        return try Data(contentsOf: url)
    }

    static func loadString(_ filename: String) throws -> String {
        let data = try load(filename)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TestFixturesError.notUTF8(filename)
        }
        return text
    }
}

enum TestFixturesError: Error {
    case notUTF8(String)
}
