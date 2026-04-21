import Foundation
import Observation

@MainActor
protocol AnalyzeViewModel: AnyObject, Observable {
    var report: AnalyzeReport? { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }

    func load()
    func refresh()
}

@MainActor
@Observable
final class DefaultAnalyzeViewModel: AnalyzeViewModel {

    private(set) var report: AnalyzeReport?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false

    private let service: AnalyzeService
    private var currentTask: Task<Void, Never>?

    init(service: AnalyzeService) {
        self.service = service
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
        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
    }

    private func performFetch() async {
        defer {
            isLoading = false
            currentTask = nil
        }
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
}
