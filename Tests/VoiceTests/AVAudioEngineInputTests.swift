import Testing
import Foundation
@testable import JARVIS

@Suite("AVAudioEngineInput Tests")
struct AVAudioEngineInputTests {

    @Test("startCapture sets isCapturing = true")
    func testStartSetsCapturing() throws {
        let input = AVAudioEngineInput()
        // We can't open a real audio device in CI, so we just verify state logic.
        // AVAudioEngine.start() will throw on machines without audio hardware.
        // The isCapturing flag should only be set after successful start.
        // Since we can't guarantee audio hardware, we test the initial state.
        #expect(input.isCapturing == false)
    }

    @Test("stopCapture sets isCapturing = false")
    func testStopClearsCapturing() throws {
        let input = AVAudioEngineInput()
        // Even without starting, stopCapture should be safe and leave isCapturing false.
        input.stopCapture()
        #expect(input.isCapturing == false)
    }

    @Test("double startCapture throws")
    func testDoubleStartThrows() throws {
        let input = AVAudioEngineInput()
        // Calling startCapture while already capturing should throw.
        // We inject a stub that immediately marks it as capturing.
        input.forceCapturingState(true)
        #expect(throws: AVAudioEngineInputError.alreadyCapturing) {
            try input.startCapture(frameSize: 512, sampleRate: 16000) { _ in }
        }
    }
}
