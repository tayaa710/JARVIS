import SwiftUI

/// Voice tab in Settings. Composes WakeWordSettingsView with STT and TTS controls.
struct VoiceSettingsView: View {

    @AppStorage("sttProvider") private var sttProvider: String = "auto"
    @AppStorage("ttsEnabled") private var ttsEnabled: Bool = true
    @AppStorage("ttsProvider") private var ttsProvider: String = "auto"
    @AppStorage("ttsVoiceModel") private var ttsVoiceModel: String = DeepgramTTSVoice.default.modelID
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
                Toggle("Enable Text-to-Speech", isOn: $ttsEnabled)

                if ttsEnabled {
                    Picker("Provider", selection: $ttsProvider) {
                        Text("Auto (Deepgram if key set, else Apple)").tag("auto")
                        Text("Deepgram").tag("deepgram")
                        Text("Apple").tag("apple")
                    }
                    .pickerStyle(.radioGroup)

                    if ttsProvider != "apple" {
                        Picker("Voice", selection: $ttsVoiceModel) {
                            ForEach(DeepgramTTSVoice.all, id: \.modelID) { voice in
                                Text(voice.displayName).tag(voice.modelID)
                            }
                        }
                    }

                    Text("Deepgram Aura-2 voices require a Deepgram API key. Apple TTS works offline with no key required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
