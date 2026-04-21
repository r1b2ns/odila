import Foundation

protocol AnalyzeCachePurging: Sendable {
    func purgeIfNeeded() async
}

/// Removes Mole's persistent analyze cache (~/.cache/mole) exactly once per
/// app session so that the first scan after a cold launch is always fresh.
/// Subsequent navigations during the same session keep the populated cache,
/// which makes Rescan instant.
actor AnalyzeCachePurger: AnalyzeCachePurging {

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
        guard !hasPurged else { return }
        hasPurged = true
        _ = try? await executor.execute(
            "/bin/rm",
            arguments: ["-rf", cacheURL.path]
        )
    }
}
