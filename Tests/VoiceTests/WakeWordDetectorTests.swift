import Testing
import Foundation
@testable import JARVIS

@Suite("WakeWordDetector Tests")
struct WakeWordDetectorTests {

    // MARK: - Helpers

    func makeDetector(
        engineResults: [Int32] = [-1],
        engineError: Error? = nil,
        grantMic: Bool = true
    ) -> (WakeWordDetectorImpl, MockWakeWordEngine, MockAudioInput, MockMicrophonePermission) {
        let engine = MockWakeWordEngine()
        engine.processResults = engineResults
        engine.processError = engineError
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        mic.grantAccess = grantMic
        let detector = WakeWordDetectorImpl(engine: engine, audioInput: audio, permissionChecker: mic)
        return (detector, engine, audio, mic)
    }

    // MARK: - Tests

    @Test("start() begins capture and sets isListening = true")
    func testStartBeginsCapture() async throws {
        let (detector, _, audio, _) = makeDetector()
        try await detector.start()
        #expect(audio.startCaptureCalled == 1)
        #expect(detector.isListening == true)
    }

    @Test("stop() ends capture, deletes engine, sets isListening = false")
    func testStopEndsCapture() async throws {
        let (detector, engine, audio, _) = makeDetector()
        try await detector.start()
        await detector.stop()
        #expect(audio.stopCaptureCalled == 1)
        #expect(engine.deleteCalled == true)
        #expect(detector.isListening == false)
    }

    @Test("pause() stops capture but does NOT delete engine")
    func testPauseStopsCaptureButKeepsEngine() async throws {
        let (detector, engine, audio, _) = makeDetector()
        try await detector.start()
        await detector.pause()
        #expect(audio.stopCaptureCalled == 1)
        #expect(engine.deleteCalled == false)
        #expect(detector.isListening == false)
    }

    @Test("resume() after pause restarts capture")
    func testResumeRestartsCapture() async throws {
        let (detector, _, audio, _) = makeDetector()
        try await detector.start()
        await detector.pause()
        try await detector.resume()
        #expect(audio.startCaptureCalled == 2)
        #expect(detector.isListening == true)
    }

    @Test("second start() throws .alreadyListening")
    func testStartWhenAlreadyListeningThrows() async throws {
        let (detector, _, _, _) = makeDetector()
        try await detector.start()
        await #expect(throws: WakeWordError.alreadyListening) {
            try await detector.start()
        }
    }

    @Test("mic permission denied throws .microphonePermissionDenied")
    func testMicPermissionDeniedThrows() async throws {
        let (detector, _, _, _) = makeDetector(grantMic: false)
        await #expect(throws: WakeWordError.microphonePermissionDenied) {
            try await detector.start()
        }
    }

    @Test("wake word callback fires when engine returns 0")
    func testWakeWordCallbackFires() async throws {
        let (detector, _, audio, _) = makeDetector(engineResults: [0])
        var detected = false
        detector.onWakeWordDetected = { detected = true }
        try await detector.start()
        audio.simulateFrames([[0, 1, 2]])
        // Allow main queue dispatch to drain
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(detected == true)
    }

    @Test("no callback when engine returns -1 (no detection)")
    func testNoFalsePositive() async throws {
        let (detector, _, audio, _) = makeDetector(engineResults: [-1])
        var detected = false
        detector.onWakeWordDetected = { detected = true }
        try await detector.start()
        audio.simulateFrames([[0, 1, 2]])
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(detected == false)
    }

    @Test("engine process error triggers onError callback")
    func testErrorCallbackOnEngineFailure() async throws {
        struct TestError: Error {}
        let (detector, _, audio, _) = makeDetector(engineError: TestError())
        var gotError = false
        detector.onError = { _ in gotError = true }
        try await detector.start()
        audio.simulateFrames([[0, 1, 2]])
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(gotError == true)
    }
}
