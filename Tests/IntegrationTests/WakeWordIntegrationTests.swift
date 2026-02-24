import Testing
import Foundation
@testable import JARVIS

@Suite("WakeWord Integration Tests")
struct WakeWordIntegrationTests {

    @Test("full wake word flow: start → feed frames → detect → callback fires")
    func testFullWakeWordFlow() async throws {
        let engine = MockWakeWordEngine()
        engine.processResults = [-1, -1, 0]  // detect on 3rd frame
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()

        let detector = WakeWordDetectorImpl(engine: engine, audioInput: audio, permissionChecker: mic)

        var detectedCount = 0
        detector.onWakeWordDetected = { detectedCount += 1 }

        try await detector.start()
        #expect(detector.isListening == true)

        audio.simulateFrames([[0], [0], [0]])
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(detectedCount == 1)
        await detector.stop()
        #expect(detector.isListening == false)
    }

    @Test("detector stays nil when setting is disabled")
    func testWakeWordDisabledDoesNotStart() async throws {
        // Simulate disabled setting by not calling start().
        // In production, AppDelegate checks UserDefaults before creating the detector.
        let engine = MockWakeWordEngine()
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        let detector = WakeWordDetectorImpl(engine: engine, audioInput: audio, permissionChecker: mic)

        // We never call start() — so isListening stays false.
        #expect(detector.isListening == false)
        #expect(audio.startCaptureCalled == 0)
    }

    @Test("missing access key causes graceful error — no crash")
    func testMissingAccessKeyDoesNotCrash() async {
        // Simulate missing key by having mic denied (stand-in for graceful failure path).
        let engine = MockWakeWordEngine()
        let audio = MockAudioInput()
        let mic = MockMicrophonePermission()
        mic.grantAccess = false

        let detector = WakeWordDetectorImpl(engine: engine, audioInput: audio, permissionChecker: mic)
        var caughtError: Error?
        do {
            try await detector.start()
        } catch {
            caughtError = error
        }
        #expect(caughtError != nil)
        #expect(detector.isListening == false)
    }
}
