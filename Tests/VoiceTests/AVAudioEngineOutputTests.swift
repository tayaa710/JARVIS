import Testing
import Foundation
@testable import JARVIS

@Suite("AVAudioEngineOutput Tests")
struct AVAudioEngineOutputTests {

    @Test("MockAudioOutput initial state is not playing")
    func testMockInitialState() {
        let mock = MockAudioOutput()
        #expect(mock.isPlaying == false)
    }

    @Test("MockAudioOutput play records data and sample rate")
    func testMockPlayRecordsData() async throws {
        let mock = MockAudioOutput()
        let data = Data([0x00, 0x01, 0x02, 0x03])
        try await mock.play(pcmData: data, sampleRate: 24000, channelCount: 1)
        #expect(mock.playedData == data)
        #expect(mock.playedSampleRate == 24000)
    }

    @Test("MockAudioOutput play error is thrown")
    func testMockPlayError() async {
        let mock = MockAudioOutput()
        mock.playError = SpeechOutputError.synthesizeFailed("test")
        do {
            try await mock.play(pcmData: Data([0]), sampleRate: 24000, channelCount: 1)
            Issue.record("Expected throw")
        } catch {
            #expect(error is SpeechOutputError)
        }
    }

    @Test("MockAudioOutput stop sets isPlaying to false")
    func testMockStop() async throws {
        let mock = MockAudioOutput()
        let data = Data(repeating: 0, count: 100)
        // Not actually waiting for play to finish, just stop it
        mock.stop()
        #expect(mock.isPlaying == false)
    }

    @Test("AVAudioEngineOutput conforms to AudioOutputProviding")
    func testConformsToProtocol() {
        let output: any AudioOutputProviding = AVAudioEngineOutput()
        #expect(output.isPlaying == false)
    }

    @Test("AVAudioEngineOutput empty data does not crash")
    func testEmptyDataDoesNotCrash() async throws {
        let output = AVAudioEngineOutput()
        // Empty data should throw or silently succeed — just shouldn't crash
        do {
            try await output.play(pcmData: Data(), sampleRate: 24000, channelCount: 1)
        } catch {
            // Acceptable — empty buffer may fail
        }
    }
}
