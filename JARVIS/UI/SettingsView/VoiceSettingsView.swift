import SwiftUI

/// Voice tab in Settings. Composes WakeWordSettingsView with STT provider controls.
struct VoiceSettingsView: View {

    @AppStorage("sttProvider") private var sttProvider: String = "auto"
    @State private var hasDeepgramKey: Bool = false

    var body: some View {
        Form {
            // Wake word detection (fully implemented in M017)
            WakeWordSettingsView()

            Section("Speech-to-Text") {
                Picker("Provider", selection: $sttProvider) {
                    Text("Auto (Deepgram if key set, else Apple)").tag("auto")
                    Text("Deepgram").tag("deepgram")
                    Text("Apple Speech").tag("apple")
                }
                .pickerStyle(.radioGroup)

                if sttProvider != "apple" {
                    if hasDeepgramKey {
                        LabeledContent("Deepgram API Key") {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Configured")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        LabeledContent("Deepgram API Key") {
                            Text("Not set — configure in API Keys tab")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Apple Speech works offline but requires macOS dictation to be enabled. Deepgram provides higher accuracy for JARVIS commands.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Text-to-Speech") {
                LabeledContent("Provider") {
                    Text("Deepgram (coming soon)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(true)
        }
        .formStyle(.grouped)
        .task {
            hasDeepgramKey = checkDeepgramKey()
        }
    }

    private func checkDeepgramKey() -> Bool {
        let keychain = KeychainHelper()
        guard let data = try? keychain.read(key: "deepgram_api_key"),
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return false }
        return true
    }
}
