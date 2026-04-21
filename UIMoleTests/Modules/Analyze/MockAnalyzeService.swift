import Foundation
@testable import UIMole

actor MockAnalyzeService: AnalyzeService {

    typealias Fetch = @Sendable (Int) async throws -> AnalyzeReport

    private(set) var callCount: Int = 0
    private let fetch: Fetch

    init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    init(result: Result<AnalyzeReport, Error>) {
        self.init { _ in try result.get() }
    }

    func fetchReport() async throws -> AnalyzeReport {
        callCount += 1
        return try await fetch(callCount)
    }
}
