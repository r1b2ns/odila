import SwiftUI

// MARK: - Containers

struct StatusSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

struct StatusBarRow: View {
    let label: String
    let percent: Double
    let trailingText: String?
    var tint: Color = .green

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            ProgressView(value: min(max(percent, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(tint)

            Text(trailingText ?? String(format: "%.1f%%", percent))
                .font(.caption.monospaced())
                .frame(width: 80, alignment: .trailing)
        }
    }
}

// MARK: - Header

struct StatusHeaderView: View {
    let snapshot: StatusSnapshot

    var body: some View {
        HStack(spacing: 16) {
            HealthBadge(score: snapshot.healthScore, label: snapshot.healthScoreMsg)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.hardware.model)
                    .font(.title2.bold())
                Text(
                    [
                        snapshot.hardware.cpuModel,
                        snapshot.hardware.totalRam,
                        snapshot.hardware.diskSize,
                        snapshot.hardware.osVersion
                    ].joined(separator: " · ")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                Text("up \(snapshot.uptime) · \(snapshot.host)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct HealthBadge: View {
    let score: Int
    let label: String

    private var tint: Color {
        switch score {
        case 80...: return .green
        case 50..<80: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
            Text(label.isEmpty ? "Health" : label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.15))
        )
        .foregroundStyle(tint)
    }
}

// MARK: - CPU

struct CPUSectionView: View {
    let cpu: StatusSnapshot.CPU

    var body: some View {
        StatusSectionCard(title: "CPU", systemImage: "cpu") {
            StatusBarRow(label: "Total", percent: cpu.usage, trailingText: nil)

            let topCores = cpu.perCore
                .enumerated()
                .sorted { $0.element > $1.element }
                .prefix(3)
            ForEach(Array(topCores), id: \.offset) { index, value in
                StatusBarRow(
                    label: "Core\(index)",
                    percent: value,
                    trailingText: nil
                )
            }

            HStack {
                Text("Load")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(
                    String(
                        format: "%.2f / %.2f / %.2f, %dP+%dE",
                        cpu.load1,
                        cpu.load5,
                        cpu.load15,
                        cpu.pCoreCount,
                        cpu.eCoreCount
                    )
                )
                .font(.caption.monospaced())
                Spacer()
            }
        }
    }
}

// MARK: - Memory

struct MemorySectionView: View {
    let memory: StatusSnapshot.Memory

    private var freePercent: Double { max(0, 100 - memory.usedPercent) }
    private var swapPercent: Double {
        guard memory.swapTotal > 0 else { return 0 }
        return Double(memory.swapUsed) / Double(memory.swapTotal) * 100
    }
    private var availBytes: Int64 { max(0, memory.total - memory.used) }

    var body: some View {
        StatusSectionCard(title: "Memory", systemImage: "memorychip") {
            StatusBarRow(label: "Used", percent: memory.usedPercent, trailingText: nil)
            StatusBarRow(label: "Free", percent: freePercent, trailingText: nil)
            StatusBarRow(
                label: "Swap",
                percent: swapPercent,
                trailingText: "\(ByteFormatter.string(memory.swapUsed)) / \(ByteFormatter.string(memory.swapTotal))"
            )
            HStack {
                Text("Total")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text("\(ByteFormatter.string(memory.used)) / \(ByteFormatter.string(memory.total))")
                    .font(.caption.monospaced())
                Spacer()
            }
            HStack {
                Text("Avail")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(ByteFormatter.string(availBytes))
                    .font(.caption.monospaced())
                Spacer()
            }
        }
    }
}

// MARK: - Disk

struct DiskSectionView: View {
    let disks: [StatusSnapshot.Disk]
    let io: StatusSnapshot.DiskIO

    var body: some View {
        StatusSectionCard(title: "Disk", systemImage: "internaldrive") {
            ForEach(disks) { disk in
                let label = disk.external ? "EXTR" : "INTR"
                StatusBarRow(
                    label: label,
                    percent: disk.usedPercent,
                    trailingText: "\(ByteFormatter.string(disk.used)) / \(ByteFormatter.string(disk.total))",
                    tint: disk.usedPercent > 90 ? .red : .green
                )
            }
            HStack {
                Text("Read")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(String(format: "%.1f MB/s", io.readRate))
                    .font(.caption.monospaced())
                Spacer()
            }
            HStack {
                Text("Write")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(String(format: "%.1f MB/s", io.writeRate))
                    .font(.caption.monospaced())
                Spacer()
            }
        }
    }
}

// MARK: - Power

struct PowerSectionView: View {
    let batteries: [StatusSnapshot.Battery]
    let thermal: StatusSnapshot.Thermal

    var body: some View {
        StatusSectionCard(title: "Power", systemImage: "bolt.fill") {
            if let battery = batteries.first {
                StatusBarRow(
                    label: "Level",
                    percent: Double(battery.percent),
                    trailingText: nil
                )
                StatusBarRow(
                    label: "Health",
                    percent: Double(battery.capacity),
                    trailingText: nil
                )
                Text("\(battery.status.capitalized) · \(battery.timeLeft)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text("\(battery.health) · \(battery.cycleCount) cycles · Battery \(String(format: "%.1f°C", thermal.batteryTemp))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("No battery detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Processes

struct ProcessesSectionView: View {
    let processes: [StatusSnapshot.TopProcess]

    var body: some View {
        StatusSectionCard(title: "Processes", systemImage: "sparkle") {
            ForEach(processes.prefix(5)) { process in
                StatusBarRow(
                    label: truncate(process.name, limit: 14),
                    percent: process.cpu,
                    trailingText: String(format: "%.1f%%", process.cpu)
                )
            }
        }
    }

    private func truncate(_ s: String, limit: Int) -> String {
        s.count > limit ? String(s.prefix(limit - 1)) + "…" : s
    }
}

// MARK: - Network

struct NetworkSectionView: View {
    let interfaces: [StatusSnapshot.Network]
    let proxy: StatusSnapshot.Proxy?

    private var primary: StatusSnapshot.Network? {
        interfaces.first(where: { !$0.ip.isEmpty }) ?? interfaces.first
    }

    var body: some View {
        StatusSectionCard(title: "Network", systemImage: "network") {
            if let primary {
                HStack {
                    Text("Down")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(String(format: "%.1f MB/s", primary.rxRateMbs))
                        .font(.caption.monospaced())
                    Spacer()
                }
                HStack {
                    Text("Up")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(String(format: "%.1f MB/s", primary.txRateMbs))
                        .font(.caption.monospaced())
                    Spacer()
                }
                if !primary.ip.isEmpty {
                    Text("\(primary.name) · \(primary.ip)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if let proxy, proxy.enabled {
                Text("Proxy \(proxy.type) · \(proxy.host)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Helpers

enum ByteFormatter {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
