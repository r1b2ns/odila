import SwiftUI

struct AnalyzeView<ViewModel: AnalyzeViewModel>: View {

    @State var viewModel: ViewModel

    var body: some View {
        Group {
            if let report = viewModel.report {
                reportList(report)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Analysis failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ScanProgressView(elapsedSeconds: viewModel.elapsedSeconds)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .navigationTitle("Analyze")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    if viewModel.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private func reportList(_ report: AnalyzeReport) -> some View {
        List {
            Section {
                ForEach(report.entries) { entry in
                    AnalyzeEntryRow(entry: entry)
                }
            } header: {
                HStack {
                    Text(report.path.isEmpty ? "/" : report.path)
                        .font(.headline.monospaced())
                    Spacer()
                    Text("Total \(ByteFormatter.string(report.totalSize))")
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AnalyzeEntryRow: View {
    let entry: AnalyzeReport.Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.body)
                    if entry.cleanable == true {
                        TagBadge(text: "Cleanable", tint: .green)
                    }
                    if entry.insight == true {
                        TagBadge(text: "Insight", tint: .blue)
                    }
                }
                Text(entry.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(sizeText)
                .font(.body.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    private var sizeText: String {
        entry.hasUnknownSize ? "—" : ByteFormatter.string(entry.size)
    }
}

private struct ScanProgressView: View {
    let elapsedSeconds: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning disk…")
                .font(.headline)
            Text(formatted)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("This can take about a minute on the first run.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var formatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TagBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(tint.opacity(0.18))
            )
            .foregroundStyle(tint)
    }
}
