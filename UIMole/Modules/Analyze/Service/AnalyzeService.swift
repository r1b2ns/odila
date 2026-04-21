import Foundation

enum AnalyzeServiceError: Error, Equatable {
    case commandFailed(exitCode: Int32, stderr: String)
}

protocol AnalyzeService: Sendable {
    func fetchReport() async throws -> AnalyzeReport
}

final class DefaultAnalyzeService: AnalyzeService {

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

    func fetchReport() async throws -> AnalyzeReport {
        let result = try await executor.execute(binaryURL.path, arguments: ["-json"])
        guard result.isSuccess else {
            throw AnalyzeServiceError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.error
            )
        }
        return try decoder.decode(AnalyzeReport.self, from: result.output)
    }
}
