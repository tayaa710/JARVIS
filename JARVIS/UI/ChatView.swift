import SwiftUI

struct ChatView: View {

    @Bindable var viewModel: ChatViewModel

    @State private var bootComplete = false
    @State private var cornerBrightness: Double = 1.0

    var body: some View {
        ZStack {
            // Base background
            JARVISTheme.jarvisBlack.ignoresSafeArea()

            // Ambient particle field
            ParticleFieldView()
                .ignoresSafeArea()

            // Scanline texture
            ScanlineOverlay()
                .ignoresSafeArea()

            // Main HUD content
            VStack(spacing: 0) {
                StatusIndicatorView(
                    status: viewModel.status,
                    onAbort: viewModel.abort
                )

                Divider()
                    .background(JARVISTheme.jarvisBlueDim)

                messageList

                Divider()
                    .background(JARVISTheme.jarvisBlueDim)

                ChatInputView(
                    inputText: $viewModel.inputText,
                    onSend: viewModel.send,
                    isEnabled: viewModel.status == .idle,
                    isListening: viewModel.isListeningForSpeech,
                    onMicTap: { viewModel.toggleListening() }
                )
            }
            .hudCornerBrackets(brightness: cornerBrightness)
            .onAppear { startCornerPulse() }

            // Boot sequence overlay
            if !bootComplete {
                BootSequenceView { bootComplete = true }
                    .transition(.opacity)
                    .zIndex(10)
            }

            // API key overlay
            if viewModel.needsAPIKey {
                apiKeyOverlay.zIndex(5)
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

    // MARK: - Corner Pulse

    private func startCornerPulse() {
        Timer.scheduledTimer(withTimeInterval: JARVISTheme.pulsePeriod / 2, repeats: true) { _ in
            withAnimation(.easeInOut(duration: JARVISTheme.pulsePeriod / 2)) {
                cornerBrightness = cornerBrightness > 0.7 ? 0.4 : 1.0
            }
        }
    }

    // MARK: - API Key Overlay

    private var apiKeyOverlay: some View {
        ZStack {
            JARVISTheme.jarvisBlack.opacity(0.96)

            VStack(spacing: 16) {
                Text("ENTER API KEY")
                    .font(JARVISTheme.jarvisOutput)
                    .foregroundStyle(JARVISTheme.jarvisCyan)

                Text("Get your key at console.anthropic.com")
                    .font(JARVISTheme.jarvisUISmall)
                    .foregroundStyle(JARVISTheme.jarvisBlue40)

                APIKeyEntry(viewModel: viewModel)
            }
            .padding(24)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .hudCornerBrackets()
            .padding(40)
        }
    }
}

// MARK: - Scanline Overlay

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                ctx.fill(Path(rect), with: .color(.black.opacity(0.03)))
                y += 4
            }
        }
        .allowsHitTesting(false)
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
            .tint(JARVISTheme.jarvisBlue)
            .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
