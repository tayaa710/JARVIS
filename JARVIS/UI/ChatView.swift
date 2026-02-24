import SwiftUI

struct ChatView: View {

    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            StatusIndicatorView(
                status: viewModel.status,
                onAbort: viewModel.abort
            )

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
        .sheet(item: $viewModel.pendingConfirmation) { pending in
            ConfirmationDialog(
                toolUse: pending.toolUse,
                onApprove: { viewModel.resolveConfirmation(approved: true) },
                onDeny: { viewModel.resolveConfirmation(approved: false) }
            )
        }
        .overlay {
            if viewModel.needsAPIKey {
                apiKeyOverlay
            }
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
                    // Anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
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
            Color(NSColor.windowBackgroundColor).opacity(0.95)

            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)

                Text("Enter your Anthropic API Key")
                    .font(.headline)

                Text("Get your key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                APIKeyEntry(viewModel: viewModel)
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)
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
