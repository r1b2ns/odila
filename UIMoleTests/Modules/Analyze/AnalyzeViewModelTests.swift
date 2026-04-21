import Foundation
import Testing
@testable import UIMole

@MainActor
struct AnalyzeViewModelTests {

    private struct DummyError: Error, LocalizedError {
        let errorDescription: String? = "analyze blew up"
    }

    @Test
    func publishesReportOnLoad() async throws {
        let expected = AnalyzeReport.fixture()
        let service = MockAnalyzeService(result: .success(expected))
        let sut = DefaultAnalyzeViewModel(service: service)

        sut.load()
        try await waitUntil { sut.report != nil }

        #expect(sut.report == expected)
        #expect(sut.errorMessage == nil)
        #expect(sut.isLoading == false)
    }

    @Test
    func purgesCacheBeforeEveryFetchAttempt() async throws {
        let purger = MockAnalyzeCachePurger()
        let service = MockAnalyzeService(result: .success(.fixture()))
        let sut = DefaultAnalyzeViewModel(service: service, cachePurger: purger)

        sut.load()
        try await waitUntil { sut.report != nil }
        sut.refresh()
        try await waitUntil(timeout: .seconds(2)) { sut.isLoading == false && sut.report != nil }

        // Small settling delay so the second fetch's awaited purge lands.
        try await Task.sleep(for: .milliseconds(50))

        // The purger is called every time the view model starts a fetch, but
        // the purger itself is responsible for making it a no-op after the
        // first run (tested in AnalyzeCachePurgerTests).
        let purgeCalls = await purger.callCount
        let serviceCalls = await service.callCount
        #expect(serviceCalls == 2)
        #expect(purgeCalls == serviceCalls)
    }

    @Test
    func setsErrorMessageWhenServiceFails() async throws {
        let service = MockAnalyzeService(result: .failure(DummyError()))
        let sut = DefaultAnalyzeViewModel(service: service)

        sut.load()
        try await waitUntil { sut.errorMessage != nil }

        #expect(sut.report == nil)
        #expect(sut.errorMessage?.contains("analyze blew up") == true)
        #expect(sut.isLoading == false)
    }

    @Test
    func loadDoesNotRefetchWhenReportPresent() async throws {
        let service = MockAnalyzeService(result: .success(.fixture()))
        let sut = DefaultAnalyzeViewModel(service: service)

        sut.load()
        try await waitUntil { sut.report != nil }

        sut.load()
        sut.load()

        try await Task.sleep(for: .milliseconds(100))
        let calls = await service.callCount
        #expect(calls == 1)
    }

    @Test
    func elapsedSecondsIncrementsWhileScanningAndStopsWhenDone() async throws {
        // Service takes ~1.5s so at least one tick lands while loading.
        let service = MockAnalyzeService { _ in
            try await Task.sleep(for: .milliseconds(1_500))
            return .fixture()
        }
        let sut = DefaultAnalyzeViewModel(service: service)

        #expect(sut.elapsedSeconds == 0)

        sut.load()
        try await waitUntil(timeout: .seconds(3)) { sut.elapsedSeconds >= 1 }
        #expect(sut.isLoading)

        try await waitUntil(timeout: .seconds(3)) { sut.report != nil }
        let frozenValue = sut.elapsedSeconds
        #expect(sut.isLoading == false)

        // After completion the ticker is stopped; the value must not keep growing.
        try await Task.sleep(for: .milliseconds(1_200))
        #expect(sut.elapsedSeconds == frozenValue)
    }

    @Test
    func refreshResetsElapsedCounter() async throws {
        let service = MockAnalyzeService { _ in
            try await Task.sleep(for: .milliseconds(1_100))
            return .fixture()
        }
        let sut = DefaultAnalyzeViewModel(service: service)

        sut.load()
        try await waitUntil(timeout: .seconds(3)) { sut.report != nil }
        #expect(sut.elapsedSeconds >= 1)

        sut.refresh()
        // The counter should immediately reset to 0 when the next scan starts.
        #expect(sut.elapsedSeconds == 0)
        sut.refresh()  // no-op equivalent: keep it a single in-flight scan
        try await waitUntil(timeout: .seconds(3)) { !sut.isLoading }
    }

    @Test
    func refreshTriggersAnotherFetch() async throws {
        let first = AnalyzeReport.fixture(path: "/alpha")
        let second = AnalyzeReport.fixture(path: "/beta")
        let service = MockAnalyzeService { call in
            call == 1 ? first : second
        }
        let sut = DefaultAnalyzeViewModel(service: service)

        sut.load()
        try await waitUntil { sut.report?.path == "/alpha" }

        sut.refresh()
        try await waitUntil { sut.report?.path == "/beta" }

        let calls = await service.callCount
        #expect(calls == 2)
        #expect(sut.errorMessage == nil)
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
