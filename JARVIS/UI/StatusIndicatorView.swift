import SwiftUI

// MARK: - Status Display Config

/// Maps AssistantStatus to a testable display configuration.
enum StatusDisplayConfig: Equatable {
    case dimDot
    case spinner(toolName: String?)
    case sonar(partial: String)
    case equalizer

    static func from(_ status: AssistantStatus) -> StatusDisplayConfig {
        switch status {
        case .idle:                    return .dimDot
        case .thinking:                return .spinner(toolName: nil)
        case .executingTool(let name): return .spinner(toolName: name)
        case .listening(let partial):  return .sonar(partial: partial)
        case .speaking:                return .equalizer
        }
    }
}

// MARK: - Status Indicator View

struct StatusIndicatorView: View {

    let status: AssistantStatus
    let onAbort: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusContent
            Spacer()
            if status != .idle {
                abortButton
            }
        }
        .padding(.horizontal, JARVISTheme.messagePadding)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        let config = StatusDisplayConfig.from(status)
        switch config {
        case .dimDot:
            idleDot

        case .spinner(let toolName):
            spinnerView(toolName: toolName)

        case .sonar(let partial):
            listeningView(partial: partial)

        case .equalizer:
            speakingView
        }
    }

    // MARK: - Idle

    private var idleDot: some View {
        Circle()
            .fill(JARVISTheme.border)
            .frame(width: 6, height: 6)
    }

    // MARK: - Spinner (Thinking / Executing Tool)

    private func spinnerView(toolName: String?) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
            if let name = toolName {
                Text("Running \(name)…")
                    .font(JARVISTheme.caption)
                    .foregroundStyle(JARVISTheme.textSecondary)
            } else {
                Text("Thinking…")
                    .font(JARVISTheme.caption)
                    .foregroundStyle(JARVISTheme.textSecondary)
            }
        }
    }

    // MARK: - Listening

    private func listeningView(partial: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)
            Text(partial.isEmpty ? "Listening…" : "\"\(partial)\"")
                .font(JARVISTheme.caption)
                .foregroundStyle(JARVISTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Speaking

    private var speakingView: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.variableColor)
            Text("Speaking…")
                .font(JARVISTheme.caption)
                .foregroundStyle(JARVISTheme.textSecondary)
        }
    }

    // MARK: - Abort Button

    private var abortButton: some View {
        Button(action: onAbort) {
            Image(systemName: "xmark.circle")
                .font(.title3)
                .foregroundStyle(JARVISTheme.textSecondary)
        }
        .buttonStyle(.plain)
        .help("Stop")
    }
}
