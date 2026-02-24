// MARK: - AudioInputProviding

public protocol AudioInputProviding: AnyObject {
    func startCapture(frameSize: Int, sampleRate: Int, onFrame: @escaping @Sendable ([Int16]) -> Void) throws
    func stopCapture()
    var isCapturing: Bool { get }
}
