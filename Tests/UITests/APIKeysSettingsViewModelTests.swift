import Testing
@testable import JARVIS

@Suite("APIKeysSettingsViewModel Tests")
@MainActor
struct APIKeysSettingsViewModelTests {

    // MARK: - loadAll

    @Test("loadAll sets status to saved when key exists in Keychain")
    func loadAllSetsSavedStatus() async throws {
        let keychain = MockKeychainHelper()
        keychain.storedData["anthropic-api-key"] = "sk-test".data(using: .utf8)!
        keychain.fakeAPIKey = nil  // disable special-case fakeAPIKey so storedData is used
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        await vm.loadAll()
        #expect(vm.anthropicStatus == .saved)
    }

    @Test("loadAll sets status to missing when key absent")
    func loadAllSetsMissingStatus() async throws {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        keychain.storedData = [:]
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        await vm.loadAll()
        #expect(vm.anthropicStatus == .missing)
        #expect(vm.picovoiceStatus == .missing)
        #expect(vm.deepgramStatus == .missing)
    }

    // MARK: - save

    @Test("Saving a key writes to Keychain and sets status to saved")
    func savingKeyUpdateStatus() async {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        vm.anthropicInput = "sk-real-key"
        await vm.save(keyName: "anthropic-api-key", value: vm.anthropicInput, status: \.anthropicStatus)
        #expect(vm.anthropicStatus == .saved)
        #expect(keychain.storedData["anthropic-api-key"] != nil)
    }

    @Test("Saving empty string is rejected and status stays missing")
    func savingEmptyStringRejected() async {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        vm.anthropicInput = ""
        await vm.save(keyName: "anthropic-api-key", value: "", status: \.anthropicStatus)
        #expect(vm.anthropicStatus == .missing)
        #expect(keychain.storedData["anthropic-api-key"] == nil)
    }

    @Test("Deleting a key clears it and sets status to missing")
    func deletingKeySetsMissing() async {
        let keychain = MockKeychainHelper()
        keychain.fakeAPIKey = nil
        keychain.storedData["anthropic-api-key"] = "sk-test".data(using: .utf8)!
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        await vm.loadAll()
        #expect(vm.anthropicStatus == .saved)
        await vm.delete(keyName: "anthropic-api-key", status: \.anthropicStatus)
        #expect(vm.anthropicStatus == .missing)
    }

    @Test("Keychain error surfaces as error message")
    func keychainErrorSurfaces() async {
        let keychain = MockKeychainHelper()
        keychain.shouldThrow = KeychainError.unexpectedStatus(-1)
        let vm = APIKeysSettingsViewModel(keychain: keychain)
        vm.anthropicInput = "sk-test"
        await vm.save(keyName: "anthropic-api-key", value: vm.anthropicInput, status: \.anthropicStatus)
        #expect(vm.errorMessage != nil)
    }
}
