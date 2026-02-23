import SwiftUI

struct MessageBubbleView: View {

    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.toolCalls.isEmpty {
                    toolCallPills
                }
            }
            .padding(.horizontal, 4)

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        HStack(spacing: 4) {
            markdownText
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if message.isStreaming {
                streamingCursor
            }
        }
    }

    private var markdownText: Text {
        if let attributed = try? AttributedString(markdown: message.text) {
            return Text(attributed)
        }
        return Text(message.text)
    }

    private var bubbleBackground: Color {
        message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }

    // MARK: - Streaming Cursor

    private var streamingCursor: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)
            .opacity(0.7)
    }

    // MARK: - Tool Call Pills

    private var toolCallPills: some View {
        ForEach(message.toolCalls) { toolCall in
            HStack(spacing: 4) {
                toolCallIcon(for: toolCall.status)
                    .font(.caption2)
                Text(toolCall.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func toolCallIcon(for status: ToolCallStatus) -> some View {
        switch status {
        case .running:
            Image(systemName: "arrow.2.circlepath")
                .foregroundStyle(.secondary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
