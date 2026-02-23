import SwiftUI

// MARK: - Height Preference Key

private struct EditorHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 40
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {

    @Binding var inputText: String
    let onSend: () -> Void
    let isEnabled: Bool

    @FocusState private var isFocused: Bool
    @State private var editorHeight: CGFloat = 40

    private let minEditorHeight: CGFloat = 40
    private let maxEditorHeight: CGFloat = 120

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextEditor(text: $inputText)
                .font(.body)
                // Use computed height — avoids fixedSize on NSScrollView which triggers
                // -layoutSubtreeIfNeeded recursion on macOS.
                .frame(height: editorHeight)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .focused($isFocused)
                .onKeyPress(.return, phases: .down) { keyPress in
                    if keyPress.modifiers.contains(.command) {
                        // Cmd+Enter = new line (insert \n)
                        inputText += "\n"
                        return .handled
                    }
                    // Enter alone = send
                    if canSend {
                        onSend()
                        return .handled
                    }
                    return .ignored
                }
                // Height oracle: a hidden Text mirror sized with fixedSize (safe on Text,
                // not on TextEditor/NSScrollView). Reports its height via PreferenceKey.
                .background(
                    Text(inputText.isEmpty ? " " : inputText)
                        .font(.body)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: EditorHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                        .opacity(0)
                        .allowsHitTesting(false)
                )
                .onPreferenceChange(EditorHeightKey.self) { height in
                    editorHeight = min(maxEditorHeight, max(minEditorHeight, height))
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var canSend: Bool {
        isEnabled && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
