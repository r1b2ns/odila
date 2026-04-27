import Foundation
import os

protocol AnalyzeProgressSourcing: Sendable {
    /// Emits a snapshot each time mole's `overview_sizes.json` is updated.
    /// Each snapshot is the full set of directories seen so far, keyed by
    /// absolute path.
    func stream() -> AsyncStream<[AnalyzeProgressEntry]>
}

struct AnalyzeProgressSource: AnalyzeProgressSourcing {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "analyze.progress"
    )

    private let overviewURL: URL
    private let pollInterval: Duration

    init(
        overviewURL: URL = AnalyzeProgressSource.defaultOverviewURL,
        pollInterval: Duration = .milliseconds(500)
    ) {
        self.overviewURL = overviewURL
        self.pollInterval = pollInterval
    }

    static var defaultOverviewURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/mole/overview_sizes.json")
    }

    func stream() -> AsyncStream<[AnalyzeProgressEntry]> {
        let url = overviewURL
        let interval = pollInterval
        Self.logger.info(
            "progress stream started — overview=\(url.path, privacy: .public)"
        )
        return AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                var lastModified: Date?
                var emissions = 0
                while !Task.isCancelled {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let mtime = attrs?[.modificationDate] as? Date
                    if mtime != lastModified {
                        lastModified = mtime
                        if let entries = Self.parse(fileAt: url) {
                            emissions += 1
                            Self.logger.debug(
                                "progress emit #\(emissions, privacy: .public) — entries=\(entries.count, privacy: .public)"
                            )
                            continuation.yield(entries)
                        } else if mtime != nil {
                            Self.logger.error(
                                "progress parse failed — overview unreadable or malformed"
                            )
                        }
                    }
                    try? await Task.sleep(for: interval)
                }
                Self.logger.info(
                    "progress stream stopped — totalEmissions=\(emissions, privacy: .public)"
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func parse(fileAt url: URL) -> [AnalyzeProgressEntry]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard
            let raw = try? JSONSerialization.jsonObject(with: data),
            let dict = raw as? [String: Any]
        else { return nil }

        var entries: [AnalyzeProgressEntry] = []
        for (path, value) in dict {
            guard
                let payload = value as? [String: Any],
                let sizeNumber = payload["size"] as? NSNumber
            else { continue }
            entries.append(
                AnalyzeProgressEntry(
                    path: path,
                    size: sizeNumber.int64Value
                )
            )
        }
        return entries
    }
}
