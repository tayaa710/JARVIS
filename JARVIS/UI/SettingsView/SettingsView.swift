import SwiftUI

struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: GeneralSettingsViewModel())
                .tabItem { Label("General", systemImage: "gearshape") }

            APIKeysSettingsView(viewModel: APIKeysSettingsViewModel())
                .tabItem { Label("API Keys", systemImage: "key") }

            VoiceSettingsView()
                .tabItem { Label("Voice", systemImage: "waveform") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
