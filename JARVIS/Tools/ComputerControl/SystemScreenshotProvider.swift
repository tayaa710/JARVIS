import Foundation
import AppKit
import CoreGraphics

// MARK: - SystemScreenshotProvider

/// Production implementation of ScreenshotProviding using CGWindowListCreateImage.
/// Not unit-tested — requires real Screen Recording permission.
struct SystemScreenshotProvider: ScreenshotProviding {

    private static let maxLongEdge: CGFloat = 1280
    private static let jpegQuality: CGFloat = 0.8

    func checkPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    func captureScreen() throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenshotError.permissionDenied
        }
        guard let cgImage = CGWindowListCreateImage(
            .infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            throw ScreenshotError.captureFailed
        }
        return try encode(cgImage)
    }

    func captureWindow(pid: pid_t) throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenshotError.permissionDenied
        }
        // Find the frontmost window belonging to the given PID.
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[CFString: Any]] else {
            throw ScreenshotError.captureFailed
        }
        let windows = windowList.filter { info in
            guard let ownerPid = info[kCGWindowOwnerPID] as? Int32 else { return false }
            return ownerPid == pid
        }
        guard let firstWindow = windows.first,
              let windowID = firstWindow[kCGWindowNumber] as? CGWindowID else {
            throw ScreenshotError.captureFailed
        }
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw ScreenshotError.captureFailed
        }
        return try encode(cgImage)
    }

    // MARK: - Private

    private func encode(_ cgImage: CGImage) throws -> Data {
        let scaled = downscaleIfNeeded(cgImage)
        let rep = NSBitmapImageRep(cgImage: scaled)
        guard let data = rep.representation(
            using: .jpeg,
            properties: [.compressionFactor: Self.jpegQuality]
        ) else {
            throw ScreenshotError.encodingFailed
        }
        return data
    }

    private func downscaleIfNeeded(_ cgImage: CGImage) -> CGImage {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longEdge = max(width, height)
        guard longEdge > Self.maxLongEdge else { return cgImage }

        let scale = Self.maxLongEdge / longEdge
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return cgImage }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? cgImage
    }
}
