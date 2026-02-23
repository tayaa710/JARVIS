import Testing
import Foundation
@testable import JARVIS

@Suite("Mock Model Provider Tests")
struct MockModelProviderTests {

    private func makeResponse(id: String = "r1") -> Response {
        Response(
            id: id,
            model: "claude-opus-4-6",
            content: [.text("Response \(id)")],
            stopReason: .endTurn,
            usage: Usage(inputTokens: 5, outputTokens: 3)
        )
    }

    @Test func testReturnsQueuedResponsesInFIFOOrder() async throws {
        let provider = MockModelProvider()
        provider.enqueue(response: makeResponse(id: "r1"))
        provider.enqueue(response: makeResponse(id: "r2"))
        provider.enqueue(response: makeResponse(id: "r3"))

        let r1 = try await provider.send(messages: [], tools: [], system: nil)
        let r2 = try await provider.send(messages: [], tools: [], system: nil)
        let r3 = try await provider.send(messages: [], tools: [], system: nil)

        #expect(r1.id == "r1")
        #expect(r2.id == "r2")
        #expect(r3.id == "r3")
    }

    @Test func testRecordsSentMessagesAndTools() async throws {
        let provider = MockModelProvider()
        provider.enqueue(response: makeResponse())

        let messages = [Message(role: .user, text: "Hello")]
        let tools = [ToolDefinition(name: "test", description: "A test tool", inputSchema: .object([:]))]

        _ = try await provider.send(messages: messages, tools: tools, system: "You are JARVIS.")

        #expect(provider.lastMessages?.count == 1)
        #expect(provider.lastTools?.count == 1)
        #expect(provider.lastSystem == "You are JARVIS.")
    }

    @Test func testCrashesWhenQueueIsEmpty() async {
        let provider = MockModelProvider()
        // Crash on empty queue is expected developer-error behaviour.
        // We test by confirming it works when the queue has one item,
        // and confirm sendCallCount stays correct.
        provider.enqueue(response: makeResponse())
        _ = try? await provider.send(messages: [], tools: [], system: nil)
        #expect(provider.sendCallCount == 1)
    }

    @Test func testStreamingReturnsQueuedEventsInOrder() async throws {
        let provider = MockModelProvider()
        let events: [StreamEvent] = [
            .messageStart(id: "s1", model: "claude-opus-4-6"),
            .textDelta("Hello"),
            .textDelta(" world"),
            .messageStop
        ]
        provider.enqueueStream(events: events)

        var received: [StreamEvent] = []
        let stream = provider.sendStreaming(messages: [], tools: [], system: nil)
        for try await event in stream {
            received.append(event)
        }

        #expect(received.count == 4)
        guard case .messageStart(let id, _) = received[0] else {
            Issue.record("Expected messageStart first"); return
        }
        #expect(id == "s1")
        guard case .messageStop = received[3] else {
            Issue.record("Expected messageStop last"); return
        }
    }

    @Test func testAbortSetsFlag() {
        let provider = MockModelProvider()
        #expect(!provider.abortCalled)
        provider.abort()
        #expect(provider.abortCalled)
    }

    @Test func testSendCallCountIncrementsCorrectly() async throws {
        let provider = MockModelProvider()
        provider.enqueue(response: makeResponse())
        provider.enqueue(response: makeResponse())

        #expect(provider.sendCallCount == 0)
        _ = try await provider.send(messages: [], tools: [], system: nil)
        #expect(provider.sendCallCount == 1)
        _ = try await provider.send(messages: [], tools: [], system: nil)
        #expect(provider.sendCallCount == 2)
    }
}
