import SwiftUI

struct APIKeysSettingsView: View {

    @State var viewModel: APIKeysSettingsViewModel

    var body: some View {
        Form {
            apiKeySection(
                title: "Anthropic (Claude)",
                placeholder: "sk-ant-…",
                input: $viewModel.anthropicInput,
                status: viewModel.anthropicStatus,
                onSave: {
                    Task { await viewModel.save(
                        keyName: "anthropic-api-key",
                        value: viewModel.anthropicInput,
                        status: \.anthropicStatus
                    )}
                },
                onDelete: {
                    Task { await viewModel.delete(
                        keyName: "anthropic-api-key",
                        status: \.anthropicStatus
                    )}
                }
            )

            apiKeySection(
                title: "Picovoice (Wake Word)",
                placeholder: "Paste from console.picovoice.ai",
                input: $viewModel.picovoiceInput,
                status: viewModel.picovoiceStatus,
                onSave: {
                    Task { await viewModel.save(
                        keyName: "picovoice_access_key",
                        value: viewModel.picovoiceInput,
                        status: \.picovoiceStatus
                    )}
                },
                onDelete: {
                    Task { await viewModel.delete(
                        keyName: "picovoice_access_key",
                        status: \.picovoiceStatus
                    )}
                }
            )

            apiKeySection(
                title: "Deepgram (Voice)",
                placeholder: "Paste from console.deepgram.com",
                input: $viewModel.deepgramInput,
                status: viewModel.deepgramStatus,
                onSave: {
                    Task { await viewModel.save(
                        keyName: "deepgram_api_key",
                        value: viewModel.deepgramInput,
                        status: \.deepgramStatus
                    )}
                },
                onDelete: {
                    Task { await viewModel.delete(
                        keyName: "deepgram_api_key",
                        status: \.deepgramStatus
                    )}
                }
            )

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { Task { await viewModel.loadAll() } }
    }

    // MARK: - Private

    @ViewBuilder
    private func apiKeySection(
        title: String,
        placeholder: String,
        input: Binding<String>,
        status: APIKeyStatus,
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        Section(title) {
            HStack {
                SecureField(placeholder, text: input)
                statusIcon(status)
            }
            HStack {
                Button("Save") { onSave() }
                    .disabled(input.wrappedValue.isEmpty)
                Spacer()
                Button("Delete", role: .destructive) { onDelete() }
                    .disabled(status == .missing)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: APIKeyStatus) -> some View {
        switch status {
        case .saved:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .missing:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
    }
}
