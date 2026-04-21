import Foundation

enum StatusServiceError: Error, Equatable {
    case commandFailed(exitCode: Int32, stderr: String)
}

protocol StatusService: Sendable {
    func fetchSnapshot() async throws -> StatusSnapshot
}

final class DefaultStatusService: StatusService {

    private let executor: CommandExecuting
    private let decoder: CommandOutputJSONDecoder
    private let binaryURL: URL

    init(
        executor: CommandExecuting,
        decoder: CommandOutputJSONDecoder,
        binaryURL: URL
    ) {
        self.executor = executor
        self.decoder = decoder
        self.binaryURL = binaryURL
    }

    func fetchSnapshot() async throws -> StatusSnapshot {
        let result = try await executor.execute(binaryURL.path, arguments: ["-json"])
        guard result.isSuccess else {
            throw StatusServiceError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.error
            )
        }
        return try decoder.decode(StatusSnapshot.self, from: result.output)
    }
}
