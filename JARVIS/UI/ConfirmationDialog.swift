import SwiftUI

struct ConfirmationDialog: View {

    let toolUse: ToolUse
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JARVIS wants to use: \(toolUse.name)")
                .font(JARVISTheme.headline)
                .foregroundStyle(JARVISTheme.textPrimary)

            if !toolUse.input.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments")
                        .font(JARVISTheme.caption)
                        .foregroundStyle(JARVISTheme.textSecondary)
                    Text(formattedArguments)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(JARVISTheme.textPrimary)
                        .padding(8)
                        .background(JARVISTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(JARVISTheme.border, lineWidth: 1)
                        )
                }
            }

            HStack {
                Button("Deny", action: onDeny)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Allow", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(JARVISTheme.assistantBubble)
    }

    private var formattedArguments: String {
        toolUse.input.map { key, value in "  \(key): \(value)" }
            .sorted()
            .joined(separator: "\n")
    }
}
