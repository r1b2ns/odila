import SwiftUI

struct SettingsView<ViewModel: SettingsViewModel>: View {

    @State var viewModel: ViewModel

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("App", value: viewModel.appName)
                LabeledContent("Version", value: viewModel.versionString)
            }

            Section("Preferences") {
                Toggle(isOn: safeModeBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safe mode")
                        Text("Preview commands before running them")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 520, minHeight: 420)
    }

    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.safeModeEnabled },
            set: { viewModel.setSafeMode(enabled: $0) }
        )
    }
}
