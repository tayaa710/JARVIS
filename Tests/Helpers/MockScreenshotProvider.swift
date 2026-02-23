import Foundation
import AppKit
import CoreGraphics
@testable import JARVIS

/// Configurable mock for ScreenshotProviding. Used in tool tests.
final class MockScreenshotProvider: ScreenshotProviding, @unchecked Sendable {

    // MARK: - Configuration

    var hasPermission: Bool = true
    var captureResult: Result<Data, Error> = .success(MockScreenshotProvider.makeTestImageData())

    // MARK: - Call tracking

    private(set) var captureScreenCallCount: Int = 0
    private(set) var captureWindowCallCount: Int = 0
    private(set) var requestPermissionCallCount: Int = 0

    private let lock = NSLock()

    // MARK: - ScreenshotProviding

    func checkPermission() -> Bool { hasPermission }

    func requestPermission() {
        lock.withLock { requestPermissionCallCount += 1 }
    }

    func captureScreen() throws -> Data {
        lock.withLock { captureScreenCallCount += 1 }
        return try captureResult.get()
    }

    func captureWindow(pid: pid_t) throws -> Data {
        lock.withLock { captureWindowCallCount += 1 }
        return try captureResult.get()
    }

    // MARK: - Helpers

    /// Creates a small 100x100 red JPEG as fake image data.
    static func makeTestImageData() -> Data {
        let size = CGSize(width: 100, height: 100)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return Data() }
        context.setFillColor(NSColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        guard let cgImage = context.makeImage() else { return Data() }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) ?? Data()
    }
}
