import Foundation
@testable import JARVIS

// MockKeychainHelper returns a pre-configured API key for ViewModel tests.
final class MockKeychainHelper: KeychainHelperProtocol, @unchecked Sendable {

    var fakeAPIKey: String? = "test-api-key-12345"
    var storedData: [String: Data] = [:]
    var shouldThrow: Error?

    func save(key: String, data: Data) throws {
        if let error = shouldThrow { throw error }
        storedData[key] = data
    }

    func read(key: String) throws -> Data? {
        if let error = shouldThrow { throw error }
        if key == "anthropic-api-key", let fakeKey = fakeAPIKey {
            return fakeKey.data(using: .utf8)
        }
        return storedData[key]
    }

    func delete(key: String) throws {
        if let error = shouldThrow { throw error }
        storedData.removeValue(forKey: key)
    }
}
