import Foundation
import Observation

@MainActor
protocol AnalyzeViewModel: AnyObject, Observable {
    var report: AnalyzeReport? { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }
    var elapsedSeconds: Int { get }

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

    private let service: AnalyzeService
    private let cachePurger: AnalyzeCachePurging?
    private var currentTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?

    init(
        service: AnalyzeService,
        cachePurger: AnalyzeCachePurging? = nil
    ) {
        self.service = service
        self.cachePurger = cachePurger
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
        startTicker()
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
}
