import SwiftUI

struct ChatView: View {

    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            StatusIndicatorView(
                status: viewModel.status,
                onAbort: viewModel.abort
            )

            Divider()

            messageList

            Divider()

            ChatInputView(
                inputText: $viewModel.inputText,
                onSend: viewModel.send,
                isEnabled: viewModel.status == .idle,
                isListening: viewModel.isListeningForSpeech,
                onMicTap: { viewModel.toggleListening() }
            )
        }
        .background(JARVISTheme.background)
        .overlay {
            if viewModel.needsAPIKey {
                apiKeyOverlay
            }
        }
        .sheet(item: $viewModel.pendingConfirmation) { pending in
            ConfirmationDialog(
                toolUse: pending.toolUse,
                onApprove: { viewModel.resolveConfirmation(approved: true) },
                onDeny:    { viewModel.resolveConfirmation(approved: false) }
            )
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
            .scrollContentBackground(.hidden)
            .background(JARVISTheme.surfacePrimary)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - API Key Overlay

    private var apiKeyOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Enter Anthropic API Key")
                    .font(JARVISTheme.headline)
                    .foregroundStyle(JARVISTheme.textPrimary)

                Text("Get your key at console.anthropic.com")
                    .font(JARVISTheme.caption)
                    .foregroundStyle(JARVISTheme.textSecondary)

                APIKeyEntry(viewModel: viewModel)
            }
            .padding(24)
            .background(JARVISTheme.assistantBubble)
            .clipShape(RoundedRectangle(cornerRadius: JARVISTheme.bubbleCornerRadius))
            .padding(40)
        }
    }
}

// MARK: - API Key Entry

private struct APIKeyEntry: View {
    var viewModel: ChatViewModel
    @State private var keyInput = ""

    var body: some View {
        VStack(spacing: 12) {
            SecureField("sk-ant-...", text: $keyInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Button("Save") {
                let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                viewModel.saveAPIKey(trimmed)
            }
            .buttonStyle(.borderedProminent)
            .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
