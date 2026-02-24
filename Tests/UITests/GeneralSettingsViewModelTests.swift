import Testing
import AppKit
@testable import JARVIS

@Suite("GeneralSettingsViewModel Tests")
@MainActor
struct GeneralSettingsViewModelTests {

    @Test("Default appearance is system")
    func defaultAppearanceIsSystem() {
        let vm = GeneralSettingsViewModel(launchAtLoginManager: MockLaunchAtLoginManager())
        #expect(vm.appearanceMode == .system)
    }

    @Test("Appearance modes map correctly to NSAppearance names")
    func appearanceModeMapping() {
        #expect(AppearanceMode.light.appearanceName == NSAppearance.Name.aqua)
        #expect(AppearanceMode.dark.appearanceName == NSAppearance.Name.darkAqua)
        #expect(AppearanceMode.system.appearanceName == nil)
    }

    @Test("launchAtLogin toggle delegates to manager")
    func launchAtLoginDelegatesToManager() {
        let manager = MockLaunchAtLoginManager()
        let vm = GeneralSettingsViewModel(launchAtLoginManager: manager)
        vm.launchAtLogin = true
        #expect(manager.isEnabled == true)
        vm.launchAtLogin = false
        #expect(manager.isEnabled == false)
    }
}
