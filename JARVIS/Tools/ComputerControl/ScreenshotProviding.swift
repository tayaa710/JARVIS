import Foundation

// MARK: - ScreenshotError

enum ScreenshotError: Error, Sendable {
    case permissionDenied
    case captureFailed
    case encodingFailed
}

// MARK: - ScreenshotProviding

protocol ScreenshotProviding: Sendable {
    func checkPermission() -> Bool
    func requestPermission()
    func captureScreen() throws -> Data
    func captureWindow(pid: pid_t) throws -> Data
}
