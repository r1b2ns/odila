import Foundation
import Observation

@MainActor
protocol UninstallViewModel: AnyObject, Observable {
    var apps: [InstalledApp] { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }
    var selectedIDs: Set<InstalledApp.ID> { get }
    var isUninstalling: Bool { get }
    var uninstallErrorMessage: String? { get }
    var safeModeEnabled: Bool { get }
    var selectedApps: [InstalledApp] { get }

    func load()
    func refresh()
    func toggleSelection(of id: InstalledApp.ID, isSelected: Bool)
    func clearSelection()
    func uninstallSelected() async
    func dismissUninstallError()
}

@MainActor
@Observable
final class DefaultUninstallViewModel: UninstallViewModel {

    private(set) var apps: [InstalledApp] = []
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false
    private(set) var selectedIDs: Set<InstalledApp.ID> = []
    private(set) var isUninstalling: Bool = false
    private(set) var uninstallErrorMessage: String?

    var safeModeEnabled: Bool { preferences?.safeModeEnabled ?? true }

    var selectedApps: [InstalledApp] {
        apps.filter { selectedIDs.contains($0.id) }
    }

    private let service: InstalledAppsService
    private let uninstallService: UninstallCommandService?
    private let preferences: PreferencesStoring?
    private var currentTask: Task<Void, Never>?

    init(
        service: InstalledAppsService,
        uninstallService: UninstallCommandService? = nil,
        preferences: PreferencesStoring? = nil
    ) {
        self.service = service
        self.uninstallService = uninstallService
        self.preferences = preferences
    }

    func load() {
        guard apps.isEmpty, currentTask == nil else { return }
        startFetch()
    }

    func refresh() {
        currentTask?.cancel()
        startFetch()
    }

    func toggleSelection(of id: InstalledApp.ID, isSelected: Bool) {
        if isSelected {
            selectedIDs.insert(id)
        } else {
            selectedIDs.remove(id)
        }
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func dismissUninstallError() {
        uninstallErrorMessage = nil
    }

    func uninstallSelected() async {
        guard let uninstallService else { return }
        let targets = selectedApps
        guard !targets.isEmpty else { return }

        isUninstalling = true
        uninstallErrorMessage = nil
        defer { isUninstalling = false }

        let dryRun = safeModeEnabled
        let names = targets.map(\.name)

        do {
            let outcome = try await uninstallService.uninstall(
                appNames: names,
                dryRun: dryRun
            )
            if outcome.isSuccess {
                // Real uninstalls change the filesystem; refresh to reflect that.
                // Dry-run leaves the list intact.
                if !dryRun {
                    clearSelection()
                    startFetch()
                } else {
                    clearSelection()
                }
            } else {
                uninstallErrorMessage = outcome.error.isEmpty
                    ? outcome.output
                    : outcome.error
            }
        } catch {
            uninstallErrorMessage = String(describing: error)
        }
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
            // Drop selections for apps that are no longer present.
            let ids = Set(result.map(\.id))
            self.selectedIDs = self.selectedIDs.intersection(ids)
        } catch {
            if Task.isCancelled { return }
            self.errorMessage = String(describing: error)
        }
    }
}
