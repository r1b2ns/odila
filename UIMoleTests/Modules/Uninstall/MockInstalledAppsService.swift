import Foundation
@testable import UIMole

actor MockInstalledAppsService: InstalledAppsService {

    typealias Fetch = @Sendable (Int) async throws -> [InstalledApp]

    private(set) var callCount: Int = 0
    private let fetch: Fetch

    init(fetch: @escaping Fetch) {
        self.fetch = fetch
    }

    init(result: Result<[InstalledApp], Error>) {
        self.init { _ in try result.get() }
    }

    func fetchApps() async throws -> [InstalledApp] {
        callCount += 1
        return try await fetch(callCount)
    }
}
