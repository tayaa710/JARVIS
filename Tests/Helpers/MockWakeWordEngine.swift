import Foundation
@testable import JARVIS

final class MockWakeWordEngine: WakeWordEngine {

    /// Results returned sequentially on each process() call. Cycles to last value when exhausted.
    var processResults: [Int32] = [-1]
    var processError: Error?
    private(set) var deleteCalled: Bool = false
    private var callCount: Int = 0

    let frameLength: Int32 = 512
    let sampleRate: Int32 = 16000

    func process(pcm: [Int16]) throws -> Int32 {
        if let err = processError { throw err }
        let index = min(callCount, processResults.count - 1)
        let result = processResults[index]
        callCount += 1
        return result
    }

    func delete() {
        deleteCalled = true
    }
}
