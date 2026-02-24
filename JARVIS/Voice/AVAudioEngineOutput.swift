import Foundation
import AVFoundation

// MARK: - AVAudioEngineOutput

/// Plays raw 16-bit linear PCM audio using AVAudioEngine + AVAudioPlayerNode.
public final class AVAudioEngineOutput: AudioOutputProviding {

    public private(set) var isPlaying: Bool = false

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    public init() {}

    public func play(pcmData: Data, sampleRate: Int, channelCount: Int) async throws {
        guard !pcmData.isEmpty else { return }

        // Stop any existing playback first
        stopInternal()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channelCount),
            interleaved: true
        ) else {
            throw SpeechOutputError.synthesizeFailed("Could not create audio format")
        }

        // Convert Data → AVAudioPCMBuffer
        let frameCapacity = AVAudioFrameCount(pcmData.count / (MemoryLayout<Int16>.size * channelCount))
        guard frameCapacity > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw SpeechOutputError.synthesizeFailed("Could not create PCM buffer")
        }
        buffer.frameLength = frameCapacity

        pcmData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            let dest = buffer.int16ChannelData?[0]
            memcpy(dest, ptr, pcmData.count)
        }

        let newEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        newEngine.attach(player)
        newEngine.connect(player, to: newEngine.mainMixerNode, format: format)

        do {
            try newEngine.start()
        } catch {
            throw SpeechOutputError.synthesizeFailed("AVAudioEngine failed to start: \(error.localizedDescription)")
        }

        self.engine = newEngine
        self.playerNode = player
        isPlaying = true

        Logger.tts.debug("AVAudioEngineOutput: playing \(pcmData.count) bytes at \(sampleRate)Hz")

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.isPlaying = false
                Logger.tts.debug("AVAudioEngineOutput: playback completed")
                cont.resume()
            }
            player.play()
        }

        stopInternal()
    }

    public func stop() {
        stopInternal()
    }

    // MARK: - Private

    private func stopInternal() {
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        isPlaying = false
    }
}
