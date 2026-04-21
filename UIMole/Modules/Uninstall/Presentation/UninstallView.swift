import AppKit
import SwiftUI

struct UninstallView<ViewModel: UninstallViewModel>: View {

    @State var viewModel: ViewModel
    @State private var showConfirmation: Bool = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.apps.isEmpty {
                ProgressView("Scanning installed apps…")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Failed to list apps",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.apps.isEmpty {
                ContentUnavailableView(
                    "No apps found",
                    systemImage: "app.dashed"
                )
            } else {
                appList
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .navigationTitle("Uninstall")
        .toolbar { toolbarContent }
        .onAppear { viewModel.load() }
        .confirmationDialog(
            confirmationTitle,
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(confirmationButtonTitle, role: .destructive) {
                Task { await viewModel.uninstallSelected() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
        .alert(
            "Uninstall failed",
            isPresented: Binding(
                get: { viewModel.uninstallErrorMessage != nil },
                set: { if !$0 { viewModel.dismissUninstallError() } }
            ),
            presenting: viewModel.uninstallErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { viewModel.dismissUninstallError() }
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !viewModel.selectedIDs.isEmpty {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Label(
                        "Uninstall \(viewModel.selectedIDs.count)",
                        systemImage: "trash"
                    )
                }
                .disabled(viewModel.isUninstalling)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.refresh()
            } label: {
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(viewModel.isLoading || viewModel.isUninstalling)
        }
    }

    // MARK: - Confirmation copy

    private var confirmationTitle: String {
        let count = viewModel.selectedIDs.count
        return count == 1 ? "Uninstall 1 app?" : "Uninstall \(count) apps?"
    }

    private var confirmationButtonTitle: String {
        viewModel.safeModeEnabled ? "Preview" : "Uninstall"
    }

    private var confirmationMessage: String {
        let names = viewModel.selectedApps.map(\.name).joined(separator: ", ")
        if viewModel.safeModeEnabled {
            return "Safe mode is on. Mole will run a dry-run and print what would be removed for: \(names)."
        } else {
            return "Mole will move the following apps and their leftovers to the Trash: \(names). This cannot be undone from UIMole."
        }
    }

    // MARK: - List

    private var appList: some View {
        List {
            Section {
                ForEach(viewModel.apps) { app in
                    InstalledAppRow(
                        app: app,
                        isSelected: viewModel.selectedIDs.contains(app.id),
                        onToggle: { isSelected in
                            viewModel.toggleSelection(of: app.id, isSelected: isSelected)
                        }
                    )
                }
            } header: {
                HStack {
                    Text("\(viewModel.apps.count) apps")
                        .font(.subheadline.monospaced())
                    Spacer()
                    if !viewModel.selectedIDs.isEmpty {
                        Button("Clear selection") {
                            viewModel.clearSelection()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
        }
    }
}

private struct InstalledAppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { isSelected },
                    set: { onToggle($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)

            AppIconView(url: app.url)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.body)
                    .lineLimit(1)
                if !app.bundleIdentifier.isEmpty {
                    Text(app.bundleIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if !app.version.isEmpty {
                Text(app.version)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            RevealInFinderButton(path: app.url.path)
        }
        .padding(.vertical, 2)
    }
}

private struct AppIconView: View {
    let url: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
