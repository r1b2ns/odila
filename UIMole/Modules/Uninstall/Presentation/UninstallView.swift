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
        .sheet(
            isPresented: Binding(
                get: { viewModel.preview != nil },
                set: { if !$0 { viewModel.dismissPreview() } }
            )
        ) {
            if let preview = viewModel.preview {
                PreviewSheet(
                    preview: preview,
                    isUninstalling: viewModel.isUninstalling,
                    onDelete: { Task { await viewModel.confirmDelete() } },
                    onDismiss: { viewModel.dismissPreview() }
                )
            }
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

private struct PreviewSheet: View {
    let preview: UninstallPreview
    let isUninstalling: Bool
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
        .confirmationDialog(
            confirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
    }

    private var confirmationTitle: String {
        let count = preview.plans.count
        return count == 1 ? "Delete 1 app?" : "Delete \(count) apps?"
    }

    private var confirmationMessage: String {
        let names = preview.plans.map(\.name).joined(separator: ", ")
        return "Mole will move these apps and their leftovers to the Trash: \(names). This cannot be undone from UIMole."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(.tint)
                Text("Dry-run preview")
                    .font(.headline)
            }
            Text("Safe mode is on — nothing was deleted. Disable Safe mode in Settings to run a real uninstall.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if preview.plans.isEmpty {
            ScrollView {
                Text(preview.rawOutput.isEmpty ? "(no output)" : preview.rawOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(preview.plans) { plan in
                        AppPlanCard(plan: plan)
                    }
                }
                .padding(20)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let summary = preview.summary {
                Label(summary, systemImage: "tray.and.arrow.down")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel", role: .cancel, action: onDismiss)
                .keyboardShortcut(.cancelAction)
                .disabled(isUninstalling)

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                if isUninstalling {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 80)
                } else {
                    Label("Delete", systemImage: "trash")
                        .frame(minWidth: 80)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(preview.plans.isEmpty || isUninstalling)
        }
        .padding(16)
    }
}

private struct AppPlanCard: View {
    let plan: UninstallPreview.AppPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.orange)
                Text(plan.name)
                    .font(.title3.weight(.semibold))
                Spacer()
                if let size = plan.size {
                    Text(size)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.15))
                        )
                }
            }

            if plan.paths.isEmpty {
                Text("No files listed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(plan.paths.count) path\(plan.paths.count == 1 ? "" : "s") to remove")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.paths, id: \.self) { path in
                            AppPlanPathRow(path: path)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct AppPlanPathRow: View {
    let path: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if let finderPath = resolvedPath {
                RevealInFinderButton(path: finderPath)
            }
        }
    }

    /// Mole writes tilde-prefixed paths (e.g. `~/Library/...`). Expand them so
    /// Finder actually accepts the reveal command.
    private var resolvedPath: String? {
        let expanded = (path as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expanded) ? expanded : nil
    }

    private var icon: String {
        if path.hasSuffix(".app") {
            return "app"
        }
        if path.hasSuffix(".plist") {
            return "doc.badge.gearshape"
        }
        return "doc"
    }
}
