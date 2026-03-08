import SwiftUI

// MARK: - Height Preference Key

private struct EditorHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 40
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Can-Send Logic (testable)

/// Pure logic extracted from ChatInputView so it can be unit-tested without a view.
enum ChatInputViewState {
    static func canSend(text: String, isEnabled: Bool, isListening: Bool) -> Bool {
        isEnabled && !isListening && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {

    @Binding var inputText: String
    let onSend: () -> Void
    let isEnabled: Bool
    let isListening: Bool
    let onMicTap: () -> Void

    @FocusState private var isFocused: Bool
    @State private var editorHeight: CGFloat = 40
    @State private var micPulse: Bool = false

    private let minEditorHeight: CGFloat = 40
    private let maxEditorHeight: CGFloat = 120

    private var canSend: Bool {
        ChatInputViewState.canSend(text: inputText, isEnabled: isEnabled, isListening: isListening)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            micButton
            inputField
            if !isListening {
                sendButton
            }
        }
        .padding(.horizontal, JARVISTheme.messagePadding)
        .padding(.vertical, 8)
        .background(JARVISTheme.jarvisBlack.opacity(0.8))
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button(action: onMicTap) {
            Image(systemName: isListening ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundStyle(isListening ? JARVISTheme.jarvisCyan : JARVISTheme.jarvisBlue40)
                .scaleEffect(micPulse ? 1.15 : 1.0)
                .animation(
                    isListening
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: micPulse
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled && !isListening)
        .padding(.bottom, 8)
        .onChange(of: isListening) { _, listening in
            micPulse = listening
        }
    }

    // MARK: - Input Field

    private var inputField: some View {
        TextEditor(text: $inputText)
            .font(JARVISTheme.jarvisUI)
            .foregroundStyle(Color.white)
            .frame(height: editorHeight)
            .scrollContentBackground(.hidden)
            .background(JARVISTheme.jarvisBlack.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? JARVISTheme.jarvisBlue : JARVISTheme.jarvisBlueDim,
                        lineWidth: 1
                    )
                    .shadow(
                        color: isFocused ? JARVISTheme.jarvisBlue.opacity(0.4) : .clear,
                        radius: 4
                    )
            )
            .focused($isFocused)
            .disabled(isListening)
            .overlay(placeholderText, alignment: .topLeading)
            .onKeyPress(.return, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.command) {
                    inputText += "\n"
                    return .handled
                }
                if canSend {
                    onSend()
                    return .handled
                }
                return .ignored
            }
            // Height oracle: a hidden Text mirror
            .background(
                Text(inputText.isEmpty ? " " : inputText)
                    .font(JARVISTheme.jarvisUI)
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
    }

    // MARK: - Placeholder

    @ViewBuilder
    private var placeholderText: some View {
        if inputText.isEmpty && !isListening {
            Text("Message JARVIS…")
                .font(JARVISTheme.jarvisUI)
                .foregroundStyle(JARVISTheme.jarvisBlue40)
                .padding(.top, 8)
                .padding(.leading, 5)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(canSend ? JARVISTheme.jarvisBlue : JARVISTheme.jarvisBlue40)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: [])
        .padding(.bottom, 8)
    }
}
