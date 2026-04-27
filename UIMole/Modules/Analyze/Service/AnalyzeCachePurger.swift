import Foundation
import os

protocol AnalyzeCachePurging: Sendable {
    func purgeIfNeeded() async
}

/// Removes Mole's persistent analyze cache (~/.cache/mole) exactly once per
/// app session so that the first scan after a cold launch is always fresh.
/// Subsequent navigations during the same session keep the populated cache,
/// which makes Rescan instant.
actor AnalyzeCachePurger: AnalyzeCachePurging {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "analyze.cache"
    )

    private let executor: CommandExecuting
    private let cacheURL: URL
    private var hasPurged = false

    init(
        executor: CommandExecuting,
        cacheURL: URL = AnalyzeCachePurger.defaultCacheURL
    ) {
        self.executor = executor
        self.cacheURL = cacheURL
    }

    static var defaultCacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/mole", isDirectory: true)
    }

    func purgeIfNeeded() async {
        guard !hasPurged else {
            Self.logger.debug("purge skipped — already purged this session")
            return
        }
        hasPurged = true
        Self.logger.info(
            "purging analyze cache — path=\(self.cacheURL.path, privacy: .public)"
        )
        let result = try? await executor.execute(
            "/bin/rm",
            arguments: ["-rf", cacheURL.path]
        )
        if let result, !result.isSuccess {
            Self.logger.error(
                "purge rm failed — exit=\(result.exitCode, privacy: .public) stderr=\(result.error, privacy: .public)"
            )
        } else if result == nil {
            Self.logger.error("purge rm threw before producing a result")
        }
    }
}
