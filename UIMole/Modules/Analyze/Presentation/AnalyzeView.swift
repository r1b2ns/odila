import SwiftUI

struct AnalyzeView<ViewModel: AnalyzeViewModel>: View {

    @State var viewModel: ViewModel
    @State private var freeBytes: Int64 = 0

    /// `true` only while there are still unscanned categories. Once every
    /// expected directory has a size, loading ornaments are hidden even if
    /// the background fetch is still finalizing the JSON.
    private var isActivelyScanning: Bool {
        viewModel.isLoading
            && viewModel.progressEntries.count < AnalyzeCategory.known.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnalyzeHeaderView(
                freeBytes: freeBytes,
                isLoading: isActivelyScanning,
                completedCount: viewModel.progressEntries.count,
                expectedCount: AnalyzeCategory.known.count
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
                    if isActivelyScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isActivelyScanning)
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
            AnalyzePartialList(entries: viewModel.progressEntries)
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
    let completedCount: Int
    let expectedCount: Int

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
                    Text("Scanning directories…, \(max(0, expectedCount - completedCount)) left")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Final results list

private struct AnalyzeResultsList: View {
    let report: AnalyzeReport

    private static let hiddenEntryNames: Set<String> = ["Old Downloads (90d+)"]

    var body: some View {
        let visibleEntries = report.entries
            .filter { !Self.hiddenEntryNames.contains($0.name) }
            .sorted { $0.size > $1.size }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                    AnalyzeResultRow(
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

private struct AnalyzeResultRow: View {
    let index: Int
    let entry: AnalyzeReport.Entry
    let totalSize: Int64

    var body: some View {
        AnalyzeRowLayout(
            index: index,
            percent: percent,
            percentText: percentText,
            isPending: entry.hasUnknownSize,
            iconName: entry.isDir ? "folder.fill" : "doc.fill",
            iconColor: .secondary,
            title: entry.name,
            titleColor: .primary,
            hasInsightMark: entry.insight == true,
            trailingText: sizeText,
            trailingColor: tint,
            showBroom: entry.cleanable == true
        )
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

// MARK: - Partial list (while scanning)

private struct AnalyzePartialList: View {

    let entries: [AnalyzeProgressEntry]

    private struct Slot: Identifiable {
        let category: AnalyzeCategory
        let progress: AnalyzeProgressEntry?

        var id: String { category.id }
        var size: Int64 { progress?.size ?? 0 }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                let runningTotal = max(1, entries.reduce(Int64(0)) { $0 + $1.size })
                let entriesByPath = Dictionary(
                    uniqueKeysWithValues: entries.map { ($0.path, $0) }
                )

                let knownPaths = Set(AnalyzeCategory.known.map(\.path))
                let knownSlots = AnalyzeCategory.known.map { category in
                    Slot(category: category, progress: entriesByPath[category.path])
                }
                let extraSlots = entries
                    .filter { !knownPaths.contains($0.path) }
                    .map { progress in
                        Slot(
                            category: AnalyzeCategory(
                                path: progress.path,
                                displayName: AnalyzeCategory.displayName(for: progress.path)
                            ),
                            progress: progress
                        )
                    }

                // Largest → smallest. Pending rows (size 0) sink to the bottom.
                let sorted = (knownSlots + extraSlots).sorted { $0.size > $1.size }

                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, slot in
                    if let progress = slot.progress {
                        AnalyzePartialRow(
                            index: index + 1,
                            progress: progress,
                            displayName: slot.category.displayName,
                            runningTotal: runningTotal
                        )
                    } else {
                        AnalyzePendingRow(
                            index: index + 1,
                            displayName: slot.category.displayName
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct AnalyzePartialRow: View {
    let index: Int
    let progress: AnalyzeProgressEntry
    let displayName: String
    let runningTotal: Int64

    var body: some View {
        AnalyzeRowLayout(
            index: index,
            percent: percent,
            percentText: String(format: "%.1f%%", percent),
            isPending: false,
            iconName: "folder.fill",
            iconColor: .secondary,
            title: displayName,
            titleColor: .primary,
            hasInsightMark: false,
            trailingText: ByteFormatter.string(progress.size),
            trailingColor: AnalyzeProgressBar.colorForPercent(percent),
            showBroom: false
        )
    }

    private var percent: Double {
        guard runningTotal > 0, progress.size > 0 else { return 0 }
        return Double(progress.size) / Double(runningTotal) * 100
    }
}

private struct AnalyzePendingRow: View {
    let index: Int
    let displayName: String

    var body: some View {
        AnalyzeRowLayout(
            index: index,
            percent: 0,
            percentText: "--",
            isPending: true,
            iconName: "folder",
            iconColor: Color.secondary.opacity(0.55),
            title: displayName,
            titleColor: Color.secondary.opacity(0.75),
            hasInsightMark: false,
            trailingText: "pending..",
            trailingColor: Color.secondary.opacity(0.55),
            showBroom: false
        )
    }
}

// MARK: - Shared row layout

private struct AnalyzeRowLayout: View {
    let index: Int
    let percent: Double
    let percentText: String
    let isPending: Bool
    let iconName: String
    let iconColor: Color
    let title: String
    let titleColor: Color
    let hasInsightMark: Bool
    let trailingText: String
    let trailingColor: Color
    let showBroom: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index).")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            AnalyzeProgressBar(percent: percent, pending: isPending)
                .frame(width: 220, height: 14)

            Text(percentText)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(trailingColor)

            Text("│")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.tertiary)

            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(titleColor)
                .lineLimit(1)

            if hasInsightMark {
                Text("•")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
            }

            Spacer()

            Text(trailingText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(trailingColor)

            if showBroom {
                Text("🧹")
                    .font(.system(size: 13))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Progress bar

struct AnalyzeProgressBar: View {
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
        if percent > 20 { return Color(red: 0.82, green: 0.75, blue: 0.24) } // olive
        if percent > 5 { return Color(red: 0.57, green: 0.45, blue: 1.0) }   // purple
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
