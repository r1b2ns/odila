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
