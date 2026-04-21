import Foundation
import Observation

@MainActor
protocol UninstallViewModel: AnyObject, Observable {
    var apps: [InstalledApp] { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }

    func load()
    func refresh()
}

@MainActor
@Observable
final class DefaultUninstallViewModel: UninstallViewModel {

    private(set) var apps: [InstalledApp] = []
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false

    private let service: InstalledAppsService
    private var currentTask: Task<Void, Never>?

    init(service: InstalledAppsService) {
        self.service = service
    }

    func load() {
        guard apps.isEmpty, currentTask == nil else { return }
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
            let result = try await service.fetchApps()
            if Task.isCancelled { return }
            self.apps = result
            self.errorMessage = nil
        } catch {
            if Task.isCancelled { return }
            self.errorMessage = String(describing: error)
        }
    }
}
