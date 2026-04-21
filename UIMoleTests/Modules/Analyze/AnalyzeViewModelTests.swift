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
