import Foundation
@testable import UIMole

actor MockUninstallCommandService: UninstallCommandService {

    struct Invocation: Sendable, Equatable {
        let names: [String]
        let dryRun: Bool
    }

    typealias Handler = @Sendable ([String], Bool) async throws -> UninstallCommandOutcome

    private(set) var invocations: [Invocation] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    init(outcome: UninstallCommandOutcome) {
        self.init { _, _ in outcome }
    }

    func uninstall(appNames: [String], dryRun: Bool) async throws -> UninstallCommandOutcome {
        invocations.append(Invocation(names: appNames, dryRun: dryRun))
        return try await handler(appNames, dryRun)
    }
}
