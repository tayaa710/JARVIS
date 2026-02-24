import SwiftUI

/// Voice tab in Settings. Composes WakeWordSettingsView with placeholder
/// sections for STT and TTS (coming in M019/M020).
struct VoiceSettingsView: View {

    var body: some View {
        Form {
            // Wake word detection (fully implemented in M017)
            WakeWordSettingsView()

            Section("Speech-to-Text") {
                LabeledContent("Provider") {
                    Text("Deepgram (coming soon)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(true)

            Section("Text-to-Speech") {
                LabeledContent("Provider") {
                    Text("Deepgram (coming soon)")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(true)
        }
        .formStyle(.grouped)
    }
}
