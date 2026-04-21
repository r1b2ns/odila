import Foundation
import Testing
@testable import UIMole

@MainActor
struct StatusViewModelTests {

    private struct DummyError: Error, LocalizedError {
        let errorDescription: String? = "boom"
    }

    @Test
    func publishesSnapshotOnStart() async throws {
        let expected = StatusSnapshot.fixture(host: "first")
        let service = MockStatusService(result: .success(expected))
        let sut = DefaultStatusViewModel(service: service)

        sut.start()
        defer { sut.stop() }

        try await waitUntil { sut.snapshot != nil }

        #expect(sut.snapshot == expected)
        #expect(sut.errorMessage == nil)
        #expect(sut.isLoading == false)
    }

    @Test
    func setsErrorMessageWhenServiceFails() async throws {
        let service = MockStatusService(result: .failure(DummyError()))
        let sut = DefaultStatusViewModel(service: service)

        sut.start()
        defer { sut.stop() }

        try await waitUntil { sut.errorMessage != nil }

        #expect(sut.snapshot == nil)
        #expect(sut.errorMessage?.contains("boom") == true)
    }

    @Test
    func startIsIdempotent() async throws {
        let service = MockStatusService(result: .success(.fixture()))
        let sut = DefaultStatusViewModel(service: service)

        sut.start()
        sut.start()
        defer { sut.stop() }

        try await waitUntil { sut.snapshot != nil }

        // Within the first 200 ms (well under the 5 s polling cadence)
        // we expect only one fetch even though start() was called twice.
        try await Task.sleep(for: .milliseconds(200))
        let calls = await service.callCount
        #expect(calls == 1)
    }

    @Test
    func stopEndsPolling() async throws {
        let service = MockStatusService(result: .success(.fixture()))
        let sut = DefaultStatusViewModel(service: service)

        sut.start()
        try await waitUntil { sut.snapshot != nil }
        sut.stop()

        let callsAfterStop = await service.callCount
        try await Task.sleep(for: .milliseconds(200))
        let callsLater = await service.callCount

        #expect(callsLater == callsAfterStop)
    }

    @Test
    func canRestartAfterStop() async throws {
        let first = StatusSnapshot.fixture(host: "alpha")
        let second = StatusSnapshot.fixture(host: "beta")
        let service = MockStatusService { call in
            call == 1 ? first : second
        }
        let sut = DefaultStatusViewModel(service: service)

        sut.start()
        try await waitUntil { sut.snapshot?.host == "alpha" }
        sut.stop()

        sut.start()
        defer { sut.stop() }
        try await waitUntil { sut.snapshot?.host == "beta" }

        #expect(sut.snapshot?.host == "beta")
    }

    // MARK: - Helpers

    /// Polls the given condition on the main actor until it becomes true
    /// or the timeout elapses.
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
