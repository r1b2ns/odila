import Foundation
import Observation

@MainActor
protocol AnalyzeViewModel: AnyObject, Observable {
    var report: AnalyzeReport? { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }
    var elapsedSeconds: Int { get }
    var progressEntries: [AnalyzeProgressEntry] { get }

    func load()
    func refresh()
}

@MainActor
@Observable
final class DefaultAnalyzeViewModel: AnalyzeViewModel {

    private(set) var report: AnalyzeReport?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false
    private(set) var elapsedSeconds: Int = 0
    private(set) var progressEntries: [AnalyzeProgressEntry] = []

    private let service: AnalyzeService
    private let cachePurger: AnalyzeCachePurging?
    private let progressSource: AnalyzeProgressSourcing?
    private var currentTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
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
        guard report == nil, currentTask == nil else { return }
        startFetch()
    }

    func refresh() {
        currentTask?.cancel()
        startFetch()
    }

    private func startFetch() {
        isLoading = true
        errorMessage = nil
        progressEntries = []
        startTicker()
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
            stopTicker()
            stopProgressStream()
        }
        await cachePurger?.purgeIfNeeded()
        if Task.isCancelled { return }
        do {
            let report = try await service.fetchReport()
            if Task.isCancelled { return }
            self.report = report
            self.errorMessage = nil
        } catch {
            if Task.isCancelled { return }
            self.errorMessage = String(describing: error)
        }
    }

    private func startTicker() {
        tickerTask?.cancel()
        elapsedSeconds = 0
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
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
