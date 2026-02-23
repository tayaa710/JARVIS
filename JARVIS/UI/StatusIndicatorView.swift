import SwiftUI

struct StatusIndicatorView: View {

    let status: AssistantStatus
    let onAbort: () -> Void

    var body: some View {
        if status != .idle {
            HStack(spacing: 8) {
                statusContent
                Spacer()
                abortButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
        }
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        switch status {
        case .idle:
            EmptyView()

        case .thinking:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Thinking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .executingTool(let name):
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Running \(name)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .speaking:
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Speaking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Abort Button

    private var abortButton: some View {
        Button(action: onAbort) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .help("Stop")
    }
}
