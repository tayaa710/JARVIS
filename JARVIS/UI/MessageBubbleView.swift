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
            return MessageLayoutConfig(alignment: .leading, hasBackground: false, isMonospaced: true)
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

    /// Max chars revealed character-by-character before snapping to full text.
    private static let revealThreshold = 150

    @State private var revealedCount: Int = 0
    @State private var revealTimer: Timer? = nil

    private var config: MessageLayoutConfig {
        MessageLayoutConfig.from(role: message.role)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if config.alignment == .trailing { Spacer(minLength: 40) }

            VStack(alignment: config.alignment == .trailing ? .trailing : .leading, spacing: 4) {
                bubbleContent
                if !message.toolCalls.isEmpty {
                    toolCallPills
                }
            }
            .padding(.horizontal, 4)

            if config.alignment == .leading { Spacer(minLength: 40) }
        }
        .padding(.horizontal, JARVISTheme.messagePadding)
        .padding(.vertical, 4)
        .onAppear { startRevealIfNeeded() }
        .onChange(of: message.isStreaming) { _, streaming in
            if !streaming { revealTimer?.invalidate(); revealTimer = nil }
        }
        .onChange(of: message.text) { _, _ in
            startRevealIfNeeded()
        }
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
        markdownText(for: displayText)
            .font(JARVISTheme.jarvisUI)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Color.black.opacity(0.5)
                    JARVISTheme.jarvisBlue10
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(JARVISTheme.jarvisBlueDim, lineWidth: 0.5)
            )
            .shadow(color: JARVISTheme.jarvisBlue.opacity(0.1), radius: 4)
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Left-border accent line
            Rectangle()
                .fill(JARVISTheme.jarvisBlue)
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 0) {
                markdownText(for: displayText)
                    .font(JARVISTheme.jarvisOutput)
                    .foregroundStyle(JARVISTheme.jarvisCyan)

                if message.isStreaming {
                    BlinkingCursor()
                }
            }
        }
    }

    private func markdownText(for text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }

    // MARK: - Character Reveal

    private var displayText: String {
        guard message.role == .assistant, message.isStreaming else {
            return message.text
        }
        if message.text.count > Self.revealThreshold {
            return message.text  // snap for long messages
        }
        return String(message.text.prefix(revealedCount))
    }

    private func startRevealIfNeeded() {
        guard message.role == .assistant, message.isStreaming else { return }
        guard message.text.count <= Self.revealThreshold else { return }
        guard revealedCount < message.text.count else { return }

        revealTimer?.invalidate()
        revealTimer = Timer.scheduledTimer(
            withTimeInterval: JARVISTheme.characterRevealInterval,
            repeats: true
        ) { timer in
            if revealedCount < message.text.count {
                revealedCount += 1
            } else {
                timer.invalidate()
                revealTimer = nil
            }
        }
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
                .font(JARVISTheme.jarvisOutputSmall)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(JARVISTheme.jarvisPurple.opacity(0.75))
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
                .foregroundStyle(JARVISTheme.jarvisCyan)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(JARVISTheme.jarvisDanger)
        }
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {

    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(JARVISTheme.jarvisBlue)
            .frame(width: 8, height: 14)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    visible.toggle()
                }
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
                    .fill(JARVISTheme.jarvisCyan)
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
