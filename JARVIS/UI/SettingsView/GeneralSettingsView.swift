import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {

    @State var viewModel: GeneralSettingsViewModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $viewModel.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
            }

            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Show / Hide JARVIS:", name: .toggleJARVIS)
            }
        }
        .formStyle(.grouped)
    }
}
