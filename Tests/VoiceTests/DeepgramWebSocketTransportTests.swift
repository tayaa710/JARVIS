import Testing
import Foundation
@testable import JARVIS

@Suite("DeepgramWebSocketTransport Tests")
struct DeepgramWebSocketTransportTests {

    private func makeTransport() -> (DeepgramWebSocketTransport, MockWebSocketTask) {
        let mockTask = MockWebSocketTask()
        let transport = DeepgramWebSocketTransport { _ in mockTask }
        return (transport, mockTask)
    }

    // MARK: - Tests

    @Test("connect() calls resume on the WebSocket task")
    func testConnectResumesTask() async throws {
        let (transport, mockTask) = makeTransport()
        let url = URL(string: "wss://api.deepgram.com/v1/listen")!
        try await transport.connect(url: url, headers: ["Authorization": "Token abc"])
        #expect(mockTask.resumeCalled == true)
    }

    @Test("send(data:) forwards binary message to task")
    func testSendDataForwardsBinaryMessage() async throws {
        let (transport, mockTask) = makeTransport()
        let url = URL(string: "wss://api.deepgram.com/v1/listen")!
        try await transport.connect(url: url, headers: [:])

        let payload = Data([0x01, 0x02, 0x03])
        try await transport.send(data: payload)

        #expect(mockTask.lastSentData == payload)
    }

    @Test("send(text:) forwards text message to task")
    func testSendTextForwardsTextMessage() async throws {
        let (transport, mockTask) = makeTransport()
        let url = URL(string: "wss://api.deepgram.com/v1/listen")!
        try await transport.connect(url: url, headers: [:])

        try await transport.send(text: #"{"type":"CloseStream"}"#)

        #expect(mockTask.lastSentText == #"{"type":"CloseStream"}"#)
    }

    @Test("receive() yields parsed DeepgramMessage from queued string messages")
    func testReceiveYieldsParsedMessages() async throws {
        let resultsJSON = """
        {"type":"Results","is_final":false,"channel":{"alternatives":[{"transcript":"hello","confidence":0.9,"words":null}]}}
        """
        let (transport, mockTask) = makeTransport()
        mockTask.receiveQueue = [.string(resultsJSON)]
        mockTask.receiveExhaustError = URLError(.networkConnectionLost)

        let url = URL(string: "wss://api.deepgram.com")!
        try await transport.connect(url: url, headers: [:])

        var received: [DeepgramMessage] = []
        do {
            for try await msg in transport.receive() {
                received.append(msg)
                if received.count >= 1 { break }
            }
        } catch { /* exhausted — expected */ }

        #expect(received.count == 1)
        if case .results(let r) = received[0] {
            #expect(r.channel?.alternatives.first?.transcript == "hello")
            #expect(r.isFinal == false)
        } else {
            Issue.record("Expected .results, got \(received[0])")
        }
    }

    @Test("close() sends CloseStream JSON then cancels task")
    func testCloseSendsCloseStreamAndCancels() async throws {
        let (transport, mockTask) = makeTransport()
        let url = URL(string: "wss://api.deepgram.com")!
        try await transport.connect(url: url, headers: [:])

        await transport.close()

        #expect(mockTask.lastSentText == #"{"type":"CloseStream"}"#)
        #expect(mockTask.cancelCalled == true)
        #expect(mockTask.cancelCode == .normalClosure)
    }
}
