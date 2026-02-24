import Foundation

// MARK: - Key Status

public enum APIKeyStatus: Equatable {
    case missing
    case saved
}

// MARK: - Key Field

public enum APIKeyField: String, CaseIterable {
    case anthropic = "anthropic-api-key"
    case picovoice = "picovoice_access_key"
    case deepgram  = "deepgram_api_key"
}

// MARK: - ViewModel

@Observable
@MainActor
public final class APIKeysSettingsViewModel {

    // MARK: Anthropic
    public var anthropicInput: String = ""
    public var anthropicStatus: APIKeyStatus = .missing

    // MARK: Picovoice
    public var picovoiceInput: String = ""
    public var picovoiceStatus: APIKeyStatus = .missing

    // MARK: Deepgram
    public var deepgramInput: String = ""
    public var deepgramStatus: APIKeyStatus = .missing

    // MARK: Error
    public var errorMessage: String?

    // MARK: Private
    private let keychain: any KeychainHelperProtocol

    // MARK: Init

    public init(keychain: any KeychainHelperProtocol = KeychainHelper()) {
        self.keychain = keychain
    }

    // MARK: - Load

    public func loadAll() async {
        anthropicStatus = loadStatus(for: APIKeyField.anthropic.rawValue)
        picovoiceStatus = loadStatus(for: APIKeyField.picovoice.rawValue)
        deepgramStatus  = loadStatus(for: APIKeyField.deepgram.rawValue)
    }

    private func loadStatus(for key: String) -> APIKeyStatus {
        do {
            if let data = try keychain.read(key: key),
               let value = String(data: data, encoding: .utf8),
               !value.isEmpty {
                return .saved
            }
            return .missing
        } catch {
            Logger.settings.warning("Could not read key \(key): \(error)")
            return .missing
        }
    }

    // MARK: - Save

    /// Save a value for the given API key field. Empty values are rejected.
    public func save(keyName: String, value: String, status: WritableKeyPath<APIKeysSettingsViewModel, APIKeyStatus>) async {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.settings.warning("Rejected empty value for key \(keyName)")
            return
        }
        do {
            guard let data = value.data(using: .utf8) else { return }
            try keychain.save(key: keyName, data: data)
            updateStatus(.saved, keyPath: keyName)
            errorMessage = nil
            Logger.settings.info("Saved API key: \(keyName)")
        } catch {
            errorMessage = "Failed to save key: \(error.localizedDescription)"
            Logger.settings.error("Failed to save API key \(keyName): \(error)")
        }
    }

    // MARK: - Delete

    /// Delete the value for the given API key field.
    public func delete(keyName: String, status: WritableKeyPath<APIKeysSettingsViewModel, APIKeyStatus>) async {
        do {
            try keychain.delete(key: keyName)
            updateStatus(.missing, keyPath: keyName)
            errorMessage = nil
            Logger.settings.info("Deleted API key: \(keyName)")
        } catch {
            errorMessage = "Failed to delete key: \(error.localizedDescription)"
            Logger.settings.error("Failed to delete API key \(keyName): \(error)")
        }
    }

    // MARK: - Private

    private func updateStatus(_ newStatus: APIKeyStatus, keyPath: String) {
        switch keyPath {
        case APIKeyField.anthropic.rawValue: anthropicStatus = newStatus
        case APIKeyField.picovoice.rawValue: picovoiceStatus = newStatus
        case APIKeyField.deepgram.rawValue:  deepgramStatus  = newStatus
        default: break
        }
    }
}
