import Foundation
import AppKit
import CoreGraphics

// MARK: - ScreenshotTool

/// Captures the current screen or frontmost window.
/// Use as a last resort when get_ui_state cannot read the UI.
final class ScreenshotTool: ToolExecutor {

    let definition = ToolDefinition(
        name: "screenshot",
        description: """
        Captures the current screen or frontmost window. Use this as a fallback when \
        get_ui_state cannot read the UI (e.g., canvas apps, video players, custom-rendered \
        controls). Always try get_ui_state first.
        """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "target": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to capture: \"screen\" (entire display) or \"window\" (frontmost window). Defaults to \"screen\"."
                    ),
                    "enum": .array([.string("screen"), .string("window")])
                ])
            ]),
            "required": .array([])
        ])
    )

    let riskLevel: RiskLevel = .safe

    private let screenshotProvider: any ScreenshotProviding
    private let cache: ScreenshotCache

    init(screenshotProvider: any ScreenshotProviding, cache: ScreenshotCache) {
        self.screenshotProvider = screenshotProvider
        self.cache = cache
    }

    func execute(id: String, arguments: [String: JSONValue]) async throws -> ToolResult {
        guard screenshotProvider.checkPermission() else {
            screenshotProvider.requestPermission()
            return ToolResult(
                toolUseId: id,
                content: "Screen Recording permission is required to take screenshots. " +
                         "Please grant permission in System Settings → Privacy & Security → Screen Recording, " +
                         "then try again.",
                isError: true
            )
        }

        let target: String
        if case .string(let t) = arguments["target"] {
            target = t
        } else {
            target = "screen"
        }

        do {
            let data: Data
            if target == "window" {
                let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
                data = try screenshotProvider.captureWindow(pid: pid)
            } else {
                data = try screenshotProvider.captureScreen()
            }

            // Decode dimensions from JPEG header if available; fall back to unknown.
            let (width, height) = jpegDimensions(from: data) ?? (0, 0)
            cache.set(data: data, mediaType: "image/jpeg", width: width, height: height)

            let sizeStr = (width > 0 && height > 0) ? "\(width)x\(height)" : "unknown size"
            Logger.screenshot.info("Screenshot captured: \(sizeStr) from target=\(target)")

            return ToolResult(
                toolUseId: id,
                content: "Screenshot captured (\(sizeStr)). Use vision_analyze to examine it.",
                isError: false
            )
        } catch ScreenshotError.permissionDenied {
            return ToolResult(
                toolUseId: id,
                content: "Screen Recording permission was denied. Please grant it in System Settings.",
                isError: true
            )
        } catch {
            Logger.screenshot.error("Screenshot capture failed: \(error)")
            return ToolResult(
                toolUseId: id,
                content: "Screenshot capture failed: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    // MARK: - Private

    /// Extract pixel dimensions from JPEG data using the SOF0/SOF2 marker.
    private func jpegDimensions(from data: Data) -> (Int, Int)? {
        guard data.count > 12 else { return nil }
        var i = 2 // skip FF D8 SOI marker
        while i + 8 < data.count {
            guard data[i] == 0xFF else { return nil }
            let marker = data[i + 1]
            let length = Int(data[i + 2]) << 8 | Int(data[i + 3])
            // SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2) contain dimensions.
            if marker == 0xC0 || marker == 0xC1 || marker == 0xC2 {
                guard i + 8 < data.count else { return nil }
                let height = Int(data[i + 5]) << 8 | Int(data[i + 6])
                let width  = Int(data[i + 7]) << 8 | Int(data[i + 8])
                return (width, height)
            }
            i += 2 + length
        }
        return nil
    }
}
