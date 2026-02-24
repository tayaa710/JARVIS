import SwiftUI
import Sparkle

struct AboutSettingsView: View {

    private let updaterController: SPUStandardUpdaterController

    init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let image = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("JARVIS")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Version \(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Updates") {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Private

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
