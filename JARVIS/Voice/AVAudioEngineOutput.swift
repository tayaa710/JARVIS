import Foundation
import AVFoundation

// MARK: - AVAudioEngineOutput

/// Plays raw 16-bit linear PCM audio using AVAudioEngine + AVAudioPlayerNode.
/// Supports persistent engine mode: call `prepareEngine()` before a batch of plays
/// to reuse the same engine across multiple buffers (eliminates setup/teardown latency).
/// Call `teardownEngine()` when done with the batch.
public final class AVAudioEngineOutput: AudioOutputProviding {

    public private(set) var isPlaying: Bool = false

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isPersistent: Bool = false
    private var preparedFormat: AVAudioFormat?

    public init() {}

    /// Prepare a persistent engine for a batch of plays.
    /// Eliminates the ~50ms engine setup per call to `play()`.
    public func prepareEngine(sampleRate: Int = 24000, channelCount: Int = 1) throws {
        teardownEngine()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channelCount),
            interleaved: true
        ) else {
            throw SpeechOutputError.synthesizeFailed("Could not create audio format")
        }

        let newEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        newEngine.attach(player)
        newEngine.connect(player, to: newEngine.mainMixerNode, format: format)

        try newEngine.start()
        player.play()

        self.engine = newEngine
        self.playerNode = player
        self.preparedFormat = format
        self.isPersistent = true

        Logger.tts.debug("AVAudioEngineOutput: persistent engine prepared (\(sampleRate)Hz)")
    }

    /// Tear down the persistent engine.
    public func teardownEngine() {
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        preparedFormat = nil
        isPersistent = false
        isPlaying = false
    }

    public func play(pcmData: Data, sampleRate: Int, channelCount: Int) async throws {
        guard !pcmData.isEmpty else { return }

        if isPersistent, let player = playerNode, let format = preparedFormat {
            // Fast path: reuse persistent engine
            try await playOnExistingEngine(pcmData: pcmData, player: player, format: format)
        } else {
            // Legacy path: create/destroy engine per call
            try await playOneShot(pcmData: pcmData, sampleRate: sampleRate, channelCount: channelCount)
        }
    }

    public func stop() {
        if isPersistent {
            // In persistent mode, just stop the player node and reset
            playerNode?.stop()
            // Re-start player so it's ready for next buffer
            playerNode?.play()
            isPlaying = false
        } else {
            stopInternal()
        }
    }

    // MARK: - Private

    private func playOnExistingEngine(pcmData: Data, player: AVAudioPlayerNode, format: AVAudioFormat) async throws {
        let channelCount = Int(format.channelCount)
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

        isPlaying = true

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.isPlaying = false
                cont.resume()
            }
        }
    }

    private func playOneShot(pcmData: Data, sampleRate: Int, channelCount: Int) async throws {
        stopInternal()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channelCount),
            interleaved: true
        ) else {
            throw SpeechOutputError.synthesizeFailed("Could not create audio format")
        }

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

    private func stopInternal() {
        playerNode?.stop()
        engine?.stop()
        playerNode = nil
        engine = nil
        isPlaying = false
    }
}
