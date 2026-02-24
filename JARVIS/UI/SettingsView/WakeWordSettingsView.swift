import SwiftUI

struct WakeWordSettingsView: View {

    @AppStorage("wakeWordEnabled") private var wakeWordEnabled: Bool = false
    @State private var accessKeyInput: String = ""
    @State private var statusMessage: String = "Stopped"

    private let keychain = KeychainHelper()
    private let accessKeyName = "picovoice_access_key"

    var body: some View {
        Form {
            Section("Wake Word") {
                Toggle("Enable \"Hey JARVIS\" wake word", isOn: $wakeWordEnabled)
                    .onChange(of: wakeWordEnabled) { _, _ in
                        updateStatus()
                    }

                LabeledContent("Wake Phrase") {
                    Text("Hey JARVIS")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Picovoice Access Key") {
                SecureField("Paste access key from console.picovoice.ai", text: $accessKeyInput)
                    .onSubmit { saveAccessKey() }

                Button("Save Key") { saveAccessKey() }
                    .disabled(accessKeyInput.isEmpty)
            }

            Section("Status") {
                LabeledContent("Detection") {
                    Text(statusMessage)
                        .foregroundStyle(statusMessage.hasPrefix("Error") ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadAccessKey() }
    }

    // MARK: - Private

    private func saveAccessKey() {
        guard !accessKeyInput.isEmpty else { return }
        do {
            let data = accessKeyInput.data(using: .utf8)!
            try keychain.save(key: accessKeyName, data: data)
            Logger.ui.info("Picovoice access key saved to Keychain")
            statusMessage = wakeWordEnabled ? "Listening" : "Stopped"
        } catch {
            Logger.ui.error("Failed to save Picovoice access key: \(error)")
            statusMessage = "Error: could not save key"
        }
    }

    private func loadAccessKey() {
        do {
            if let data = try keychain.read(key: accessKeyName),
               let value = String(data: data, encoding: .utf8) {
                accessKeyInput = value
            }
        } catch {
            Logger.ui.warning("Could not load Picovoice access key: \(error)")
        }
        updateStatus()
    }

    private func updateStatus() {
        statusMessage = wakeWordEnabled ? "Listening" : "Stopped"
    }
}
