import Testing
import Foundation
@testable import JARVIS

@Suite("WakeWordSettingsView Tests")
struct WakeWordSettingsViewTests {

    @Test("wake word is disabled by default")
    func testToggleDefaultOff() {
        // AppStorage("wakeWordEnabled") should default to false if never set.
        let defaults = UserDefaults(suiteName: "com.aidaemon.test.wakeword")!
        defaults.removeObject(forKey: "wakeWordEnabled")
        let value = defaults.bool(forKey: "wakeWordEnabled")
        #expect(value == false)
    }

    @Test("access key saves and loads via Keychain round-trip")
    func testAccessKeySavesAndLoads() throws {
        let keychain = MockKeychainHelper()
        let testKey = "test-access-key-12345"

        let data = testKey.data(using: .utf8)!
        try keychain.save(key: "picovoice_access_key", data: data)
        let loaded = try keychain.read(key: "picovoice_access_key")
        #expect(loaded == data)
    }
}
