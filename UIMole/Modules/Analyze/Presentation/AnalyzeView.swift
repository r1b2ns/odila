import SwiftUI

struct AnalyzeView<ViewModel: AnalyzeViewModel>: View {

    @State var viewModel: ViewModel
    @State private var freeBytes: Int64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnalyzeHeaderView(
                freeBytes: freeBytes,
                isLoading: viewModel.isLoading,
                elapsedSeconds: viewModel.elapsedSeconds
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            content
        }
        .frame(minWidth: 820, minHeight: 560)
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
        .task { await loadFreeSpace() }
    }

    @ViewBuilder
    private var content: some View {
        if let report = viewModel.report {
            AnalyzeResultsList(report: report)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView(
                "Analysis failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else {
            AnalyzePlaceholderList()
        }
    }

    private func loadFreeSpace() async {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let free = attrs[.systemFreeSize] as? NSNumber {
            freeBytes = free.int64Value
        }
    }
}

// MARK: - Header

private struct AnalyzeHeaderView: View {
    let freeBytes: Int64
    let isLoading: Bool
    let elapsedSeconds: Int

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Analyze Disk")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if freeBytes > 0 {
                        Text("(\(ByteFormatter.string(freeBytes)) free)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Select a location to explore:")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning directories… \(formattedElapsed)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var formattedElapsed: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Results list

private struct AnalyzeResultsList: View {
    let report: AnalyzeReport

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(report.entries.enumerated()), id: \.element.id) { index, entry in
                    AnalyzeEntryRow(
                        index: index + 1,
                        entry: entry,
                        totalSize: report.totalSize
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct AnalyzeEntryRow: View {
    let index: Int
    let entry: AnalyzeReport.Entry
    let totalSize: Int64

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index).")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            AnalyzeProgressBar(percent: percent, pending: entry.hasUnknownSize)
                .frame(width: 220, height: 14)

            Text(percentText)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(tint)

            Text("│")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)

            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(entry.name)
                .font(.system(size: 13))
                .lineLimit(1)

            if entry.insight == true {
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
            }

            Spacer()

            Text(sizeText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(tint)

            if entry.cleanable == true {
                Text("🧹")
                    .font(.system(size: 13))
            }
        }
        .padding(.vertical, 2)
    }

    private var percent: Double {
        guard totalSize > 0, entry.size > 0 else { return 0 }
        return Double(entry.size) / Double(totalSize) * 100
    }

    private var percentText: String {
        entry.hasUnknownSize ? "--" : String(format: "%.1f%%", percent)
    }

    private var sizeText: String {
        entry.hasUnknownSize ? "pending.." : ByteFormatter.string(entry.size)
    }

    private var tint: Color {
        if entry.hasUnknownSize { return .secondary }
        return AnalyzeProgressBar.colorForPercent(percent)
    }
}

// MARK: - Placeholder list (while scanning)

private struct AnalyzePlaceholderList: View {
    private let placeholderCount = 14

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(0..<placeholderCount, id: \.self) { index in
                    AnalyzePlaceholderRow(index: index + 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct AnalyzePlaceholderRow: View {
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index).")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            AnalyzeProgressBar(percent: 0, pending: true)
                .frame(width: 220, height: 14)

            Text("--")
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text("│")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)

            Image(systemName: "folder")
                .foregroundStyle(.tertiary)
                .frame(width: 18)

            Text("pending..")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)

            Spacer()

            Text("pending..")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Progress bar

private struct AnalyzeProgressBar: View {
    let percent: Double
    let pending: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                DashedBackground()
                if !pending, percent > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.colorForPercent(percent))
                        .frame(width: max(2, geo.size.width * percent / 100))
                }
            }
        }
    }

    static func colorForPercent(_ percent: Double) -> Color {
        if percent > 20 { return Color(red: 0.82, green: 0.75, blue: 0.24) } // mole's olive/yellow
        if percent > 5 { return Color(red: 0.57, green: 0.45, blue: 1.0) }    // mole's purple
        return .secondary
    }
}

private struct DashedBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let dot: CGFloat = 2
            let spacing: CGFloat = 4
            let color = Color.secondary.opacity(0.22)
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                let offset: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                var x = offset
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: dot, height: dot)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
