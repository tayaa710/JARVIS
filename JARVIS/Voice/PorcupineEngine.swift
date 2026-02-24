import Foundation
import PvPorcupine

// MARK: - PorcupineEngineError

public enum PorcupineEngineError: Error {
    case initFailed(String)
    case processFailed(String)
    case resourceNotFound(String)
}

// MARK: - PorcupineEngine

/// Thin wrapper over the Porcupine C SDK implementing WakeWordEngine.
/// No unit tests — thin vendor wrapper tested via integration only.
public final class PorcupineEngine: WakeWordEngine {

    private var handle: OpaquePointer?

    public var frameLength: Int32 { pv_porcupine_frame_length() }
    public var sampleRate: Int32 { pv_sample_rate() }

    /// - Parameter accessKey: Picovoice access key from console.picovoice.ai
    public init(accessKey: String) throws {
        guard let modelPath = Bundle.main.path(forResource: "porcupine_params", ofType: "pv") else {
            throw PorcupineEngineError.resourceNotFound("porcupine_params.pv not found in app bundle")
        }
        guard let keywordPath = Bundle.main.path(forResource: "jarvis_mac", ofType: "ppn") else {
            throw PorcupineEngineError.resourceNotFound("jarvis_mac.ppn not found in app bundle")
        }

        let sensitivity: Float = 0.7
        let device = "best"
        let status = withUnsafePointer(to: sensitivity) { sensitivityPtr in
            keywordPath.withCString { kwPath in
                modelPath.withCString { mdlPath in
                    accessKey.withCString { akStr in
                        device.withCString { devStr in
                            let kwPaths: [UnsafePointer<CChar>?] = [kwPath]
                            return kwPaths.withUnsafeBufferPointer { kwBuf in
                                pv_porcupine_init(akStr, mdlPath, devStr, 1, kwBuf.baseAddress, sensitivityPtr, &handle)
                            }
                        }
                    }
                }
            }
        }

        guard status == PV_STATUS_SUCCESS else {
            throw PorcupineEngineError.initFailed("pv_porcupine_init failed with status \(status.rawValue)")
        }
        Logger.wakeWord.info("PorcupineEngine initialised (frameLength: \(frameLength), sampleRate: \(sampleRate))")
    }

    public func process(pcm: [Int16]) throws -> Int32 {
        var keywordIndex: Int32 = -1
        let status = pcm.withUnsafeBufferPointer { buf in
            pv_porcupine_process(handle, buf.baseAddress, &keywordIndex)
        }
        guard status == PV_STATUS_SUCCESS else {
            throw PorcupineEngineError.processFailed("pv_porcupine_process failed with status \(status.rawValue)")
        }
        return keywordIndex
    }

    public func delete() {
        pv_porcupine_delete(handle)
        handle = nil
        Logger.wakeWord.info("PorcupineEngine deleted")
    }
}
