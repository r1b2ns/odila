import AppKit
import SwiftUI

struct SettingsView<ViewModel: SettingsViewModel>: View {

    @State var viewModel: ViewModel
    @State private var showLicense = false

    private var projectURL: URL {
        URL(string: "https://github.com/r1b2ns/ui-mole")!
    }

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

            Section("Project") {
                Button {
                    NSWorkspace.shared.open(projectURL)
                } label: {
                    Label("View on GitHub", systemImage: "link")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    showLicense = true
                } label: {
                    Label("License", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 520, minHeight: 420)
        .sheet(isPresented: $showLicense) {
            LicenseView()
        }
    }

    private var safeModeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.safeModeEnabled },
            set: { viewModel.setSafeMode(enabled: $0) }
        )
    }
}
