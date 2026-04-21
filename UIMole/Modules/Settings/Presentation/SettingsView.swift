import SwiftUI

struct SettingsView<ViewModel: SettingsViewModel>: View {

    let viewModel: ViewModel

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("App", value: viewModel.appName)
                LabeledContent("Version", value: viewModel.versionString)
            }

            Section("Preferences") {
                Text("No preferences available yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 520, minHeight: 420)
    }
}
