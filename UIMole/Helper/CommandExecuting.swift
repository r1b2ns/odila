import Foundation

protocol CommandExecuting: Sendable {
    func execute(
        _ executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String]?
    ) async throws -> CommandResult
}

extension CommandExecuting {
    func execute(_ executable: String, arguments: [String] = []) async throws -> CommandResult {
        try await execute(
            executable,
            arguments: arguments,
            currentDirectory: nil,
            environment: nil
        )
    }
}
