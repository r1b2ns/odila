import AppKit
import SwiftUI

struct UninstallView<ViewModel: UninstallViewModel>: View {

    @State var viewModel: ViewModel

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
        .toolbar {
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
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear { viewModel.load() }
    }

    private var appList: some View {
        List {
            Section {
                ForEach(viewModel.apps) { app in
                    InstalledAppRow(app: app)
                }
            } header: {
                HStack {
                    Text("\(viewModel.apps.count) apps")
                        .font(.subheadline.monospaced())
                    Spacer()
                }
            }
        }
    }
}

private struct InstalledAppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
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
