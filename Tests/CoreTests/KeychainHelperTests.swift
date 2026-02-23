import Testing
import Foundation
@testable import JARVIS

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {

    // Isolated service name so tests never touch real app Keychain entries.
    let helper = KeychainHelper(service: "com.aidaemon.test")

    // MARK: - Helpers

    private func uniqueKey() -> String {
        "test-\(UUID().uuidString)"
    }

    // MARK: - Tests

    @Test func testSaveAndRead() throws {
        let key = uniqueKey()
        let data = Data("secret".utf8)

        try helper.save(key: key, data: data)
        let result = try helper.read(key: key)
        defer { try? helper.delete(key: key) }

        #expect(result == data)
    }

    @Test func testReadNonexistent() throws {
        let result = try helper.read(key: "nonexistent-\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test func testDelete() throws {
        let key = uniqueKey()
        let data = Data("to-delete".utf8)

        try helper.save(key: key, data: data)
        try helper.delete(key: key)
        let result = try helper.read(key: key)

        #expect(result == nil)
    }

    @Test func testOverwrite() throws {
        let key = uniqueKey()
        defer { try? helper.delete(key: key) }

        try helper.save(key: key, data: Data("value1".utf8))
        try helper.save(key: key, data: Data("value2".utf8))
        let result = try helper.read(key: key)

        #expect(result == Data("value2".utf8))
    }

    @Test func testSaveAndReadString() throws {
        let key = uniqueKey()
        defer { try? helper.delete(key: key) }

        try helper.saveString(key: key, value: "hello keychain")
        let result = try helper.readString(key: key)

        #expect(result == "hello keychain")
    }

    @Test func testDeleteNonexistent() throws {
        // Deleting a key that doesn't exist must not throw.
        try helper.delete(key: "ghost-\(UUID().uuidString)")
        #expect(true)
    }
}
