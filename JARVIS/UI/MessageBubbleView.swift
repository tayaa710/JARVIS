import SwiftUI

// MARK: - Bubble Alignment

enum BubbleAlignment: Equatable {
    case leading
    case trailing
}

// MARK: - Message Layout Config

struct MessageLayoutConfig: Equatable {
    let alignment: BubbleAlignment
    let hasBackground: Bool
    let isMonospaced: Bool

    static func from(role: Role) -> MessageLayoutConfig {
        switch role {
        case .user:
            return MessageLayoutConfig(alignment: .trailing, hasBackground: true, isMonospaced: false)
        case .assistant:
            return MessageLayoutConfig(alignment: .leading, hasBackground: true, isMonospaced: false)
        }
    }
}

// MARK: - Tool Call Pill State

enum ToolCallPillState: Equatable {
    case loading
    case checkmark
    case failure

    static func from(status: ToolCallStatus) -> ToolCallPillState {
        switch status {
        case .running:   return .loading
        case .completed: return .checkmark
        case .failed:    return .failure
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {

    let message: ChatMessage

    private var config: MessageLayoutConfig {
        MessageLayoutConfig.from(role: message.role)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if config.alignment == .trailing { Spacer(minLength: 60) }

            VStack(alignment: config.alignment == .trailing ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.toolCalls.isEmpty {
                    toolCallPills
                }
            }
            .padding(.horizontal, 4)

            if config.alignment == .leading { Spacer(minLength: 60) }
        }
        .padding(.horizontal, JARVISTheme.messagePadding)
        .padding(.vertical, 4)
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        if message.role == .user {
            userBubble
        } else {
            assistantBubble
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            markdownText(for: message.text)
                .font(JARVISTheme.body)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(JARVISTheme.userBubble)
                .clipShape(RoundedRectangle(cornerRadius: JARVISTheme.bubbleCornerRadius))
        }
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            markdownText(for: message.text)
                .font(JARVISTheme.body)
                .foregroundStyle(JARVISTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(JARVISTheme.assistantBubble)
                .clipShape(RoundedRectangle(cornerRadius: JARVISTheme.bubbleCornerRadius))

            if message.isStreaming {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.leading, 4)
            }
        }
    }

    private func markdownText(for text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }

    // MARK: - Tool Call Pills

    private var toolCallPills: some View {
        ForEach(message.toolCalls) { toolCall in
            ToolCallPill(toolCall: toolCall)
        }
    }
}

// MARK: - Tool Call Pill

private struct ToolCallPill: View {

    let toolCall: ToolCallInfo

    var body: some View {
        HStack(spacing: 4) {
            pillIcon
            Text(toolCall.name)
                .font(JARVISTheme.caption)
                .foregroundStyle(JARVISTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(JARVISTheme.pillBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var pillIcon: some View {
        let pillState = ToolCallPillState.from(status: toolCall.status)
        switch pillState {
        case .loading:
            LoadingDots()
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(JARVISTheme.danger)
        }
    }
}

// MARK: - Loading Dots

private struct LoadingDots: View {

    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(JARVISTheme.textSecondary)
                    .frame(width: 3, height: 3)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
