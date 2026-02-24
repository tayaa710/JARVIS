// MARK: - WakeWordEngine

public protocol WakeWordEngine: AnyObject {
    /// Process a frame of PCM audio. Returns keyword index (≥0) or -1 if none detected.
    func process(pcm: [Int16]) throws -> Int32
    func delete()
    var frameLength: Int32 { get }
    var sampleRate: Int32 { get }
}
