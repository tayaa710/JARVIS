import Testing
import Foundation
@testable import JARVIS

@Suite("SpeechOutputProviding Tests")
struct SpeechOutputProvidingTests {

    @Test("SpeechOutputError is Equatable")
    func testSpeechOutputErrorEquatable() {
        #expect(SpeechOutputError.apiKeyMissing == SpeechOutputError.apiKeyMissing)
        #expect(SpeechOutputError.alreadySpeaking == SpeechOutputError.alreadySpeaking)
        #expect(SpeechOutputError.textTooLong == SpeechOutputError.textTooLong)
        #expect(SpeechOutputError.synthesizeFailed("err") == SpeechOutputError.synthesizeFailed("err"))
        #expect(SpeechOutputError.synthesizeFailed("a") != SpeechOutputError.synthesizeFailed("b"))
        #expect(SpeechOutputError.apiKeyMissing != SpeechOutputError.alreadySpeaking)
    }

    @Test("MockSpeechOutput conforms to SpeechOutputProviding")
    func testMockConformsToProtocol() {
        let mock: any SpeechOutputProviding = MockSpeechOutput()
        #expect(mock.isSpeaking == false)
    }

    @Test("MockSpeechOutput speak() records call")
    func testMockSpeakRecordsCall() async throws {
        let mock = MockSpeechOutput()
        try await mock.speak(text: "hello")
        #expect(mock.speakCallCount == 1)
        #expect(mock.lastSpokenText == "hello")
    }

    @Test("MockSpeechOutput stop() records call")
    func testMockStopRecordsCall() async {
        let mock = MockSpeechOutput()
        await mock.stop()
        #expect(mock.stopCallCount == 1)
    }
}
