import Foundation
import Observation
import os

@MainActor
protocol AnalyzeViewModel: AnyObject, Observable {
    var report: AnalyzeReport? { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }
    var progressEntries: [AnalyzeProgressEntry] { get }

    func load()
    func refresh()
}

@MainActor
@Observable
final class DefaultAnalyzeViewModel: AnalyzeViewModel {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "analyze.viewmodel"
    )

    private(set) var report: AnalyzeReport?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false
    private(set) var progressEntries: [AnalyzeProgressEntry] = []

    private let service: AnalyzeService
    private let cachePurger: AnalyzeCachePurging?
    private let progressSource: AnalyzeProgressSourcing?
    private var currentTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    init(
        service: AnalyzeService,
        cachePurger: AnalyzeCachePurging? = nil,
        progressSource: AnalyzeProgressSourcing? = nil
    ) {
        self.service = service
        self.cachePurger = cachePurger
        self.progressSource = progressSource
    }

    func load() {
        guard report == nil, currentTask == nil else {
            Self.logger.debug(
                "load skipped — hasReport=\(self.report != nil, privacy: .public) inflight=\(self.currentTask != nil, privacy: .public)"
            )
            return
        }
        Self.logger.info("load started")
        startFetch()
    }

    func refresh() {
        Self.logger.info("refresh requested — cancelling inflight task")
        currentTask?.cancel()
        startFetch()
    }

    private func startFetch() {
        isLoading = true
        errorMessage = nil
        progressEntries = []
        startProgressStream()
        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
    }

    private func performFetch() async {
        defer {
            isLoading = false
            currentTask = nil
            stopProgressStream()
        }
        await cachePurger?.purgeIfNeeded()
        if Task.isCancelled {
            Self.logger.info("fetch cancelled after cache purge")
            return
        }
        do {
            let report = try await service.fetchReport()
            if Task.isCancelled {
                Self.logger.info("fetch cancelled after service returned")
                return
            }
            self.report = report
            self.errorMessage = nil
            Self.logger.info(
                "fetch completed — entries=\(report.entries.count, privacy: .public) totalBytes=\(report.totalSize, privacy: .public)"
            )
        } catch {
            if Task.isCancelled {
                Self.logger.info("fetch cancelled during error handling")
                return
            }
            let message = String(describing: error)
            self.errorMessage = message
            Self.logger.error(
                "fetch failed — error=\(message, privacy: .public)"
            )
        }
    }

    private func startProgressStream() {
        progressTask?.cancel()
        guard let progressSource else { return }
        let stream = progressSource.stream()
        progressTask = Task { @MainActor [weak self] in
            for await snapshot in stream {
                if Task.isCancelled { return }
                self?.mergeProgress(snapshot)
            }
        }
    }

    private func stopProgressStream() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func mergeProgress(_ snapshot: [AnalyzeProgressEntry]) {
        // Merge by path; latest wins. Keeps previously-seen entries in view if
        // mole rewrites the overview file mid-scan and temporarily drops some.
        var dict = Dictionary(uniqueKeysWithValues: progressEntries.map { ($0.path, $0) })
        for entry in snapshot {
            dict[entry.path] = entry
        }
        progressEntries = dict.values.sorted { $0.size > $1.size }
    }
}
