import Foundation
@testable import JARVIS

/// Mock AudioOutputProviding for tests.
final class MockAudioOutput: AudioOutputProviding {

    private(set) var isPlaying: Bool = false
    private(set) var playedData: Data?
    private(set) var playedSampleRate: Int?
    private(set) var playedChannelCount: Int?
    private(set) var playCallCount = 0
    private(set) var stopCallCount = 0

    var playError: Error?

    func play(pcmData: Data, sampleRate: Int, channelCount: Int) async throws {
        playCallCount += 1
        playedData = pcmData
        playedSampleRate = sampleRate
        playedChannelCount = channelCount
        if let error = playError { throw error }
        isPlaying = true
        isPlaying = false
    }

    func stop() {
        stopCallCount += 1
        isPlaying = false
    }
}
