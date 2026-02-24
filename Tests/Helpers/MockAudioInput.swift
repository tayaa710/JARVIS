import Foundation
@testable import JARVIS

final class MockAudioInput: AudioInputProviding {

    private(set) var startCaptureCalled: Int = 0
    private(set) var stopCaptureCalled: Int = 0
    private(set) var isCapturing: Bool = false
    private(set) var capturedOnFrame: (@Sendable ([Int16]) -> Void)?

    func startCapture(frameSize: Int, sampleRate: Int, onFrame: @escaping @Sendable ([Int16]) -> Void) throws {
        startCaptureCalled += 1
        isCapturing = true
        capturedOnFrame = onFrame
    }

    func stopCapture() {
        stopCaptureCalled += 1
        isCapturing = false
    }

    /// Feeds synthetic PCM frames through the captured callback.
    func simulateFrames(_ frames: [[Int16]]) {
        for frame in frames {
            capturedOnFrame?(frame)
        }
    }
}
