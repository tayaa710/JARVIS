import Foundation

// MARK: - AudioOutputProviding

public protocol AudioOutputProviding: AnyObject {
    var isPlaying: Bool { get }
    func play(pcmData: Data, sampleRate: Int, channelCount: Int) async throws
    func stop()
}
