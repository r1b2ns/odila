import Foundation
import Testing
@testable import UIMole

@MainActor
struct UninstallViewModelTests {

    private struct DummyError: Error, LocalizedError {
        let errorDescription: String? = "scan failed"
    }

    @Test
    func publishesAppsOnLoad() async throws {
        let fixtureApps = [
            InstalledApp(
                name: "Alpha",
                bundleIdentifier: "com.example.alpha",
                version: "1.0",
                url: URL(fileURLWithPath: "/Applications/Alpha.app")
            )
        ]
        let service = MockInstalledAppsService(result: .success(fixtureApps))
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }

        #expect(sut.apps == fixtureApps)
        #expect(sut.errorMessage == nil)
        #expect(sut.isLoading == false)
    }

    @Test
    func setsErrorMessageOnFailure() async throws {
        let service = MockInstalledAppsService(result: .failure(DummyError()))
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { sut.errorMessage != nil }

        #expect(sut.apps.isEmpty)
        #expect(sut.errorMessage?.contains("scan failed") == true)
        #expect(sut.isLoading == false)
    }

    @Test
    func loadDoesNotRefetchWhenAlreadyLoaded() async throws {
        let service = MockInstalledAppsService(result: .success([
            InstalledApp(
                name: "Alpha",
                bundleIdentifier: "com.example.alpha",
                version: "1",
                url: URL(fileURLWithPath: "/A.app")
            )
        ]))
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.load()
        sut.load()

        try await Task.sleep(for: .milliseconds(100))
        let calls = await service.callCount
        #expect(calls == 1)
    }

    @Test
    func togglesSelection() async throws {
        let app = InstalledApp(
            name: "Alpha",
            bundleIdentifier: "x.a",
            version: "1",
            url: URL(fileURLWithPath: "/A.app")
        )
        let service = MockInstalledAppsService(result: .success([app]))
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }

        #expect(sut.selectedIDs.isEmpty)
        sut.toggleSelection(of: app.id, isSelected: true)
        #expect(sut.selectedIDs == [app.id])
        #expect(sut.selectedApps == [app])

        sut.toggleSelection(of: app.id, isSelected: false)
        #expect(sut.selectedIDs.isEmpty)
    }

    @Test
    func uninstallSelectedInvokesCommandServiceWithNames() async throws {
        let apps = [
            InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app")),
            InstalledApp(name: "Beta", bundleIdentifier: "x.b", version: "2", url: URL(fileURLWithPath: "/B.app"))
        ]
        let listService = MockInstalledAppsService(result: .success(apps))
        let command = MockUninstallCommandService(
            outcome: UninstallCommandOutcome(exitCode: 0, output: "", error: "")
        )
        let prefs = InMemoryPreferencesStore(safeModeEnabled: false)
        let sut = DefaultUninstallViewModel(
            service: listService,
            uninstallService: command,
            preferences: prefs
        )

        sut.load()
        try await waitUntil { sut.apps.count == 2 }

        sut.toggleSelection(of: apps[0].id, isSelected: true)
        sut.toggleSelection(of: apps[1].id, isSelected: true)

        await sut.uninstallSelected()

        let invocations = await command.invocations
        #expect(invocations.count == 1)
        #expect(invocations.first?.names == ["Alpha", "Beta"])
        #expect(invocations.first?.dryRun == false)
        #expect(sut.isUninstalling == false)
    }

    @Test
    func uninstallRespectsSafeModeAsDryRun() async throws {
        let app = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let moleDryRunOutput = """
        \u{001B}[0;33m→ DRY RUN MODE\u{001B}[0m, No app files or settings will be modified

        ◎ Alpha , 8.0MB
          ✓ /Applications/Alpha.app
          ✓ ~/Library/Preferences/com.example.alpha.plist

        Would remove 1 app, would free 8.0MB: Alpha
        """
        let command = MockUninstallCommandService(
            outcome: UninstallCommandOutcome(
                exitCode: 0,
                output: moleDryRunOutput,
                error: ""
            )
        )
        let prefs = InMemoryPreferencesStore(safeModeEnabled: true)
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([app])),
            uninstallService: command,
            preferences: prefs
        )

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.toggleSelection(of: app.id, isSelected: true)

        await sut.uninstallSelected()

        let invocations = await command.invocations
        #expect(invocations.first?.dryRun == true)
        // Dry-run leaves apps in the list (nothing was actually removed).
        #expect(sut.apps.count == 1)
        // The parsed preview is exposed to the view.
        let preview = try #require(sut.preview)
        #expect(preview.plans.count == 1)
        #expect(preview.plans.first?.name == "Alpha")
        #expect(preview.plans.first?.size == "8.0MB")
        #expect(preview.plans.first?.paths.count == 2)
        // Selection is cleared after the preview is produced.
        #expect(sut.selectedIDs.isEmpty)

        sut.dismissPreview()
        #expect(sut.preview == nil)
    }

    @Test
    func confirmDeleteInvokesCommandServiceWithoutDryRun() async throws {
        let app = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let dryRunOutput = """
        ◎ Alpha , 8.0MB
          ✓ /Applications/Alpha.app
        Would remove 1 app, would free 8.0MB: Alpha
        """
        let command = MockUninstallCommandService { names, dryRun in
            if dryRun {
                return UninstallCommandOutcome(
                    exitCode: 0,
                    output: dryRunOutput,
                    error: ""
                )
            } else {
                return UninstallCommandOutcome(exitCode: 0, output: "moved to trash", error: "")
            }
        }
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([app])),
            uninstallService: command,
            preferences: InMemoryPreferencesStore(safeModeEnabled: true)
        )

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.toggleSelection(of: app.id, isSelected: true)

        await sut.uninstallSelected()
        #expect(sut.preview != nil)

        await sut.confirmDelete()

        let invocations = await command.invocations
        #expect(invocations.count == 2)
        #expect(invocations[0].dryRun == true)
        #expect(invocations[1].dryRun == false)
        #expect(invocations[1].names == ["Alpha"])
        // Preview is cleared after the real delete completes.
        #expect(sut.preview == nil)
    }

    @Test
    func confirmDeleteSurfacesErrorOnFailure() async throws {
        let app = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let dryRunOutput = """
        ◎ Alpha , 8.0MB
          ✓ /Applications/Alpha.app
        """
        let command = MockUninstallCommandService { _, dryRun in
            if dryRun {
                return UninstallCommandOutcome(exitCode: 0, output: dryRunOutput, error: "")
            }
            return UninstallCommandOutcome(exitCode: 127, output: "", error: "mo: command not found")
        }
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([app])),
            uninstallService: command,
            preferences: InMemoryPreferencesStore(safeModeEnabled: true)
        )

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.toggleSelection(of: app.id, isSelected: true)

        await sut.uninstallSelected()
        await sut.confirmDelete()

        #expect(sut.uninstallErrorMessage == "mo: command not found")
        // Preview stays so the user can retry.
        #expect(sut.preview != nil)
    }

    @Test
    func confirmDeleteWithoutPreviewIsNoOp() async throws {
        let command = MockUninstallCommandService(
            outcome: UninstallCommandOutcome(exitCode: 0, output: "", error: "")
        )
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([])),
            uninstallService: command,
            preferences: InMemoryPreferencesStore(safeModeEnabled: true)
        )

        await sut.confirmDelete()

        let invocations = await command.invocations
        #expect(invocations.isEmpty)
    }

    @Test
    func realUninstallDoesNotPopulatePreview() async throws {
        let app = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let command = MockUninstallCommandService(
            outcome: UninstallCommandOutcome(exitCode: 0, output: "moved to trash", error: "")
        )
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([app])),
            uninstallService: command,
            preferences: InMemoryPreferencesStore(safeModeEnabled: false)
        )

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.toggleSelection(of: app.id, isSelected: true)

        await sut.uninstallSelected()

        #expect(sut.preview == nil)
    }

    @Test
    func uninstallFailureSurfacesErrorMessage() async throws {
        let app = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let command = MockUninstallCommandService(
            outcome: UninstallCommandOutcome(
                exitCode: 127,
                output: "",
                error: "mo: command not found"
            )
        )
        let sut = DefaultUninstallViewModel(
            service: MockInstalledAppsService(result: .success([app])),
            uninstallService: command,
            preferences: InMemoryPreferencesStore(safeModeEnabled: false)
        )

        sut.load()
        try await waitUntil { !sut.apps.isEmpty }
        sut.toggleSelection(of: app.id, isSelected: true)

        await sut.uninstallSelected()

        #expect(sut.uninstallErrorMessage == "mo: command not found")
        sut.dismissUninstallError()
        #expect(sut.uninstallErrorMessage == nil)
    }

    @Test
    func refreshDropsSelectionsForAppsNoLongerPresent() async throws {
        let first = InstalledApp(name: "Alpha", bundleIdentifier: "x.a", version: "1", url: URL(fileURLWithPath: "/A.app"))
        let second = InstalledApp(name: "Beta", bundleIdentifier: "x.b", version: "2", url: URL(fileURLWithPath: "/B.app"))
        let service = MockInstalledAppsService { call in
            call == 1 ? [first, second] : [second]
        }
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { sut.apps.count == 2 }
        sut.toggleSelection(of: first.id, isSelected: true)
        sut.toggleSelection(of: second.id, isSelected: true)

        sut.refresh()
        try await waitUntil { sut.apps.count == 1 }

        // First is gone; its selection is cleaned up. Second remains selected.
        #expect(sut.selectedIDs == [second.id])
    }

    @Test
    func refreshTriggersAnotherFetch() async throws {
        let firstBatch = [
            InstalledApp(
                name: "A",
                bundleIdentifier: "x.a",
                version: "1",
                url: URL(fileURLWithPath: "/A.app")
            )
        ]
        let secondBatch = [
            InstalledApp(
                name: "B",
                bundleIdentifier: "x.b",
                version: "2",
                url: URL(fileURLWithPath: "/B.app")
            )
        ]
        let service = MockInstalledAppsService { call in
            call == 1 ? firstBatch : secondBatch
        }
        let sut = DefaultUninstallViewModel(service: service)

        sut.load()
        try await waitUntil { sut.apps.first?.bundleIdentifier == "x.a" }

        sut.refresh()
        try await waitUntil { sut.apps.first?.bundleIdentifier == "x.b" }

        let calls = await service.callCount
        #expect(calls == 2)
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: Duration = .seconds(2),
        step: Duration = .milliseconds(20),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: step)
        }
        Issue.record("Timed out waiting for condition")
    }
}
