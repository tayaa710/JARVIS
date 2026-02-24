import Foundation
@testable import JARVIS

final class MockMicrophonePermission: MicrophonePermissionChecking {

    var grantAccess: Bool = true
    var status: MicPermissionStatus = .granted

    func requestAccess() async -> Bool {
        grantAccess
    }

    func authorizationStatus() -> MicPermissionStatus {
        status
    }
}
