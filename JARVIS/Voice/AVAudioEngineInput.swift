import AVFoundation

// MARK: - AVAudioEngineInputError

public enum AVAudioEngineInputError: Error, Equatable {
    case alreadyCapturing
    case engineStartFailed(String)
}

// MARK: - AVAudioEngineInput

public final class AVAudioEngineInput: AudioInputProviding {

    private let engine = AVAudioEngine()
    private var sampleBuffer: [Int16] = []
    private var targetFrameSize: Int = 512
    private var onFrame: (@Sendable ([Int16]) -> Void)?

    public private(set) var isCapturing: Bool = false

    public init() {}

    /// Test-only hook to force the internal capturing state without touching hardware.
    func forceCapturingState(_ value: Bool) {
        isCapturing = value
    }

    public func startCapture(
        frameSize: Int,
        sampleRate: Int,
        onFrame: @escaping @Sendable ([Int16]) -> Void
    ) throws {
        guard !isCapturing else {
            throw AVAudioEngineInputError.alreadyCapturing
        }

        targetFrameSize = frameSize
        self.onFrame = onFrame
        sampleBuffer.removeAll()

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Request 16 kHz mono Int16 from the tap via AVAudioConverter
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        ) else {
            throw AVAudioEngineInputError.engineStartFailed("Could not create target audio format")
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw AVAudioEngineInputError.engineStartFailed("Could not create audio converter")
        }

        let bufferSize = AVAudioFrameCount(hardwareFormat.sampleRate * 0.032) // ~32ms
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hardwareFormat) {
            [weak self] buffer, _ in
            self?.handleBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AVAudioEngineInputError.engineStartFailed(error.localizedDescription)
        }

        isCapturing = true
        Logger.wakeWord.info("AVAudioEngineInput started capture (frameSize: \(frameSize), sampleRate: \(sampleRate))")
    }

    public func stopCapture() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        sampleBuffer.removeAll()
        onFrame = nil
        isCapturing = false
        Logger.wakeWord.info("AVAudioEngineInput stopped capture")
    }

    // MARK: - Private

    private func handleBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(targetFormat.sampleRate * 0.032) + 1
        ) else { return }

        var error: NSError?
        var inputConsumed = false

        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return buffer
        }

        guard status != .error, error == nil else {
            Logger.wakeWord.error("Audio conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }

        guard let channelData = convertedBuffer.int16ChannelData else { return }
        let frameCount = Int(convertedBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        sampleBuffer.append(contentsOf: samples)

        while sampleBuffer.count >= targetFrameSize {
            let frame = Array(sampleBuffer.prefix(targetFrameSize))
            sampleBuffer.removeFirst(targetFrameSize)
            onFrame?(frame)
        }
    }
}
