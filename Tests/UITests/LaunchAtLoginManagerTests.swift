import Testing
@testable import JARVIS

@Suite("LaunchAtLoginManager Tests")
struct LaunchAtLoginManagerTests {

    @Test("MockLaunchAtLoginManager starts disabled")
    func mockStartsDisabled() {
        let manager = MockLaunchAtLoginManager()
        #expect(manager.isEnabled == false)
    }

    @Test("MockLaunchAtLoginManager toggle on/off changes stored value")
    func mockToggle() {
        let manager = MockLaunchAtLoginManager()
        manager.isEnabled = true
        #expect(manager.isEnabled == true)
        manager.isEnabled = false
        #expect(manager.isEnabled == false)
    }
}
