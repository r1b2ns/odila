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
    func streamsProgressEntriesWhileScanning() async throws {
        // Service blocks for ~400ms so progress snapshots arrive mid-fetch.
        let service = MockAnalyzeService { _ in
            try await Task.sleep(for: .milliseconds(400))
            return .fixture()
        }
        let progress = MockAnalyzeProgressSource(
            snapshots: [
                [AnalyzeProgressEntry(path: "/a", size: 100)],
                [
                    AnalyzeProgressEntry(path: "/a", size: 100),
                    AnalyzeProgressEntry(path: "/b", size: 300)
                ]
            ],
            interval: .milliseconds(50)
        )
        let sut = DefaultAnalyzeViewModel(service: service, progressSource: progress)

        sut.load()
        try await waitUntil { sut.progressEntries.count == 2 }

        // Entries sorted by size desc.
        #expect(sut.progressEntries.first?.path == "/b")
        #expect(sut.progressEntries.last?.path == "/a")

        // Once the fetch completes, the stream is stopped.
        try await waitUntil { sut.report != nil }
        #expect(sut.isLoading == false)
    }

    @Test
    func refreshResetsProgressEntries() async throws {
        let service = MockAnalyzeService { _ in
            try await Task.sleep(for: .milliseconds(300))
            return .fixture()
        }
        let progress = MockAnalyzeProgressSource(
            snapshots: [[AnalyzeProgressEntry(path: "/a", size: 100)]],
            interval: .milliseconds(20)
        )
        let sut = DefaultAnalyzeViewModel(service: service, progressSource: progress)

        sut.load()
        try await waitUntil { !sut.progressEntries.isEmpty }
        try await waitUntil { sut.report != nil }

        sut.refresh()
        #expect(sut.progressEntries.isEmpty)
        try await waitUntil { !sut.isLoading }
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
