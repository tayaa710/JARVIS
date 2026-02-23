import Foundation

// Parsed SSE event (event name + data payload).
struct SSEEvent: Sendable {
    let event: String
    let data: String
}

// SSEParser converts a raw byte stream into parsed SSE events.
// Handles partial chunks, comment lines, and streams without trailing blank lines.
struct SSEParser: Sendable {

    static func parse(stream: AsyncThrowingStream<Data, Error>) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    var currentEvent = ""
                    var dataLines: [String] = []

                    for try await chunk in stream {
                        guard let text = String(data: chunk, encoding: .utf8) else { continue }
                        buffer += text

                        // Process every complete line in the buffer.
                        while let newlineIndex = buffer.firstIndex(of: "\n") {
                            let rawLine = String(buffer[..<newlineIndex])
                            buffer = String(buffer[buffer.index(after: newlineIndex)...])

                            // Strip optional trailing \r (CRLF line endings).
                            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

                            if line.isEmpty {
                                // Blank line = event separator. Yield accumulated event.
                                if !dataLines.isEmpty {
                                    let data = dataLines.joined(separator: "\n")
                                    let eventName = currentEvent.isEmpty ? "message" : currentEvent
                                    continuation.yield(SSEEvent(event: eventName, data: data))
                                }
                                currentEvent = ""
                                dataLines = []
                            } else if line.hasPrefix(":") {
                                // Comment line — skip.
                            } else if line.hasPrefix("event:") {
                                currentEvent = String(line.dropFirst("event:".count))
                                    .trimmingCharacters(in: .init(charactersIn: " "))
                            } else if line.hasPrefix("data:") {
                                let payload = String(line.dropFirst("data:".count))
                                    .trimmingCharacters(in: .init(charactersIn: " "))
                                dataLines.append(payload)
                            }
                        }
                    }

                    // Process any remaining partial line in the buffer (no trailing \n).
                    if !buffer.isEmpty {
                        let rawLine = buffer
                        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
                        if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst("event:".count))
                                .trimmingCharacters(in: .init(charactersIn: " "))
                        } else if line.hasPrefix("data:") {
                            let payload = String(line.dropFirst("data:".count))
                                .trimmingCharacters(in: .init(charactersIn: " "))
                            dataLines.append(payload)
                        }
                    }

                    // Flush any buffered event not followed by a final blank line.
                    if !dataLines.isEmpty {
                        let data = dataLines.joined(separator: "\n")
                        let eventName = currentEvent.isEmpty ? "message" : currentEvent
                        continuation.yield(SSEEvent(event: eventName, data: data))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
