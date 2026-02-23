import Testing
import Foundation
@testable import JARVIS

@Suite("SSE Parser Tests")
struct SSEParserTests {

    // Helper: create a stream that yields one Data chunk per string.
    private func makeStream(_ chunks: [String]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk.data(using: .utf8)!)
            }
            continuation.finish()
        }
    }

    // Helper: collect all events from a parsed stream.
    private func collect(_ stream: AsyncThrowingStream<SSEEvent, Error>) async throws -> [SSEEvent] {
        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    @Test func testParseSingleTextEvent() async throws {
        let sse = "event: message_start\ndata: {\"type\":\"message_start\"}\n\n"
        let events = try await collect(SSEParser.parse(stream: makeStream([sse])))

        #expect(events.count == 1)
        #expect(events[0].event == "message_start")
        #expect(events[0].data == "{\"type\":\"message_start\"}")
    }

    @Test func testParseMultipleEventsInSequence() async throws {
        let sse = """
        event: message_start\ndata: {"id":"1"}\n\nevent: content_block_delta\ndata: {"text":"hi"}\n\n
        """
        let events = try await collect(SSEParser.parse(stream: makeStream([sse])))

        #expect(events.count == 2)
        #expect(events[0].event == "message_start")
        #expect(events[1].event == "content_block_delta")
    }

    @Test func testHandlePingEvent() async throws {
        let sse = "event: ping\ndata: {\"type\":\"ping\"}\n\n"
        let events = try await collect(SSEParser.parse(stream: makeStream([sse])))

        #expect(events.count == 1)
        #expect(events[0].event == "ping")
    }

    @Test func testHandlePartialDataChunksSplitAcrossYields() async throws {
        // The event is split across 3 chunks — simulating TCP fragmentation.
        let chunks = [
            "event: content",
            "_block_delta\ndata:",
            " {\"text\":\"hi\"}\n\n"
        ]
        let events = try await collect(SSEParser.parse(stream: makeStream(chunks)))

        #expect(events.count == 1)
        #expect(events[0].event == "content_block_delta")
        #expect(events[0].data == "{\"text\":\"hi\"}")
    }

    @Test func testHandleStreamEndWithoutTrailingBlankLine() async throws {
        // No trailing \n\n — the parser should flush the last accumulated event.
        let sse = "event: message_stop\ndata: {\"type\":\"message_stop\"}"
        let events = try await collect(SSEParser.parse(stream: makeStream([sse])))

        #expect(events.count == 1)
        #expect(events[0].event == "message_stop")
    }

    @Test func testSkipCommentLines() async throws {
        let sse = ": this is a comment\nevent: ping\ndata: {}\n\n"
        let events = try await collect(SSEParser.parse(stream: makeStream([sse])))

        #expect(events.count == 1)
        #expect(events[0].event == "ping")
    }
}
