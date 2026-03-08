import SwiftUI

struct ConfirmationDialog: View {

    let toolUse: ToolUse
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("JARVIS WANTS TO USE: \(toolUse.name.uppercased())")
                .font(JARVISTheme.jarvisOutput)
                .foregroundStyle(JARVISTheme.jarvisCyan)

            if !toolUse.input.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ARGUMENTS:")
                        .font(JARVISTheme.jarvisOutputSmall)
                        .foregroundStyle(JARVISTheme.jarvisBlue40)
                    Text(formattedArguments)
                        .font(JARVISTheme.jarvisOutputSmall)
                        .foregroundStyle(JARVISTheme.jarvisBlue)
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(JARVISTheme.jarvisBlueDim, lineWidth: 1)
                        )
                }
            }

            HStack {
                Button("Deny", action: onDeny)
                    .buttonStyle(.bordered)
                    .tint(JARVISTheme.jarvisDanger)
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Allow", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .tint(JARVISTheme.jarvisBlue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(JARVISTheme.jarvisBlack)
        .hudCornerBrackets()
    }

    private var formattedArguments: String {
        toolUse.input.map { key, value in "  \(key): \(value)" }
            .sorted()
            .joined(separator: "\n")
    }
}
