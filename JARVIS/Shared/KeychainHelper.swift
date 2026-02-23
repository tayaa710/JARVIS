import Foundation
import Security

// MARK: - Protocol

public protocol KeychainHelperProtocol: Sendable {
    func save(key: String, data: Data) throws
    func read(key: String) throws -> Data?
    func delete(key: String) throws
}

// MARK: - Errors

public enum KeychainError: Error, Equatable {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case encodingError
}

// MARK: - Implementation

public struct KeychainHelper: KeychainHelperProtocol {
    public let service: String

    public init(service: String = "com.aidaemon") {
        self.service = service
    }

    // MARK: Save

    public func save(key: String, data: Data) throws {
        let query = baseQuery(key: key)
        let attributes: [CFString: Any] = [kSecValueData: data]

        let addQuery = query.merging([kSecValueData: data]) { $1 }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            Logger.keychain.info("Saved item for key: \(key)")
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                Logger.keychain.error("Failed to update item for key: \(key), status: \(updateStatus)")
                throw KeychainError.unexpectedStatus(updateStatus)
            }
            Logger.keychain.info("Updated item for key: \(key)")
        default:
            Logger.keychain.error("Failed to save item for key: \(key), status: \(addStatus)")
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    // MARK: Read

    public func read(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            Logger.keychain.debug("Read item for key: \(key)")
            return item as? Data
        case errSecItemNotFound:
            Logger.keychain.debug("No item found for key: \(key)")
            return nil
        default:
            Logger.keychain.error("Failed to read item for key: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Delete

    public func delete(key: String) throws {
        let query = baseQuery(key: key)
        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            Logger.keychain.info("Deleted item for key: \(key)")
        default:
            Logger.keychain.error("Failed to delete item for key: \(key), status: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: String Convenience

    public func saveString(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(key: key, data: data)
    }

    public func readString(key: String) throws -> String? {
        guard let data = try read(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private

    private func baseQuery(key: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }
}
