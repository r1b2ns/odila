import Foundation
import Observation
import os

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
    var preview: UninstallPreview? { get }

    func load()
    func refresh()
    func toggleSelection(of id: InstalledApp.ID, isSelected: Bool)
    func clearSelection()
    func uninstallSelected() async
    func confirmDelete() async
    func dismissUninstallError()
    func dismissPreview()
}

@MainActor
@Observable
final class DefaultUninstallViewModel: UninstallViewModel {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "uninstall.viewmodel"
    )

    private(set) var apps: [InstalledApp] = []
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false
    private(set) var selectedIDs: Set<InstalledApp.ID> = []
    private(set) var isUninstalling: Bool = false
    private(set) var uninstallErrorMessage: String?
    private(set) var preview: UninstallPreview?

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

    func dismissPreview() {
        preview = nil
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

        Self.logger.info(
            "uninstallSelected — names=\(names, privacy: .public) dryRun=\(dryRun, privacy: .public)"
        )

        do {
            let outcome = try await uninstallService.uninstall(
                appNames: names,
                dryRun: dryRun
            )
            if outcome.isSuccess {
                if dryRun {
                    // Surface the mole dry-run output so the user can see what
                    // would happen; the file system is untouched.
                    preview = UninstallPreviewParser.parse(outcome.output)
                    clearSelection()
                    Self.logger.info("uninstallSelected — dry-run preview ready")
                } else {
                    clearSelection()
                    startFetch()
                    Self.logger.info("uninstallSelected — uninstall completed")
                }
            } else {
                let message = Self.combinedMessage(outcome: outcome)
                Self.logger.error(
                    "uninstallSelected — failure exit=\(outcome.exitCode, privacy: .public) message=\(message, privacy: .public)"
                )
                uninstallErrorMessage = message
            }
        } catch {
            Self.logger.error(
                "uninstallSelected — threw error=\(String(describing: error), privacy: .public)"
            )
            uninstallErrorMessage = String(describing: error)
        }
    }

    func confirmDelete() async {
        guard let uninstallService else { return }
        guard let preview, !preview.plans.isEmpty else { return }

        isUninstalling = true
        uninstallErrorMessage = nil
        defer { isUninstalling = false }

        let names = preview.plans.map(\.name)

        Self.logger.info(
            "confirmDelete — names=\(names, privacy: .public)"
        )

        do {
            let outcome = try await uninstallService.uninstall(
                appNames: names,
                dryRun: false
            )
            if outcome.isSuccess {
                self.preview = nil
                clearSelection()
                startFetch()
                Self.logger.info("confirmDelete — uninstall completed")
            } else {
                let message = Self.combinedMessage(outcome: outcome)
                Self.logger.error(
                    "confirmDelete — failure exit=\(outcome.exitCode, privacy: .public) message=\(message, privacy: .public)"
                )
                uninstallErrorMessage = message
            }
        } catch {
            Self.logger.error(
                "confirmDelete — threw error=\(String(describing: error), privacy: .public)"
            )
            uninstallErrorMessage = String(describing: error)
        }
    }

    /// Mole writes the human-readable failure (e.g. "Admin access denied") to
    /// stdout while pushing low-level diagnostics ("/dev/tty: Device not
    /// configured") to stderr. Joining both keeps the actionable line visible
    /// to the user.
    private static func combinedMessage(outcome: UninstallCommandOutcome) -> String {
        let stdout = outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = outcome.error.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (stdout.isEmpty, stderr.isEmpty) {
        case (true, true):
            return "mo exited with code \(outcome.exitCode)."
        case (false, true):
            return stdout
        case (true, false):
            return stderr
        case (false, false):
            return "\(stdout)\n\n\(stderr)"
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
