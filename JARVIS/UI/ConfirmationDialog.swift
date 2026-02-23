import SwiftUI

struct ConfirmationDialog: View {

    let toolUse: ToolUse
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JARVIS wants to use: \(toolUse.name)")
                .font(.headline)

            if !toolUse.input.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedArguments)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
    }

    private var formattedArguments: String {
        let pairs = toolUse.input.map { key, value in
            "  \(key): \(value)"
        }.sorted()
        return pairs.joined(separator: "\n")
    }
}
