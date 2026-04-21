import Foundation
@testable import UIMole

actor MockStatusService: StatusService {

    typealias Fetch = @Sendable (Int) async throws -> StatusSnapshot

    private(set) var callCount: Int = 0
    private let fetch: Fetch

    init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    init(result: Result<StatusSnapshot, Error>) {
        self.init { _ in try result.get() }
    }

    func fetchSnapshot() async throws -> StatusSnapshot {
        callCount += 1
        return try await fetch(callCount)
    }
}
