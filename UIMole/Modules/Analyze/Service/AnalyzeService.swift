import Foundation
import os

enum AnalyzeServiceError: Error, Equatable {
    case commandFailed(exitCode: Int32, stderr: String)
}

protocol AnalyzeService: Sendable {
    func fetchReport() async throws -> AnalyzeReport
}

final class DefaultAnalyzeService: AnalyzeService {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "analyze.service"
    )

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
        Self.logger.info(
            "Running analyze — binary=\(self.binaryURL.path, privacy: .public)"
        )
        let start = Date()
        let result = try await executor.execute(binaryURL.path, arguments: ["-json"])
        let elapsed = Date().timeIntervalSince(start)
        guard result.isSuccess else {
            Self.logger.error(
                """
                analyze failed — exit=\(result.exitCode, privacy: .public) elapsed=\(String(format: "%.2f", elapsed), privacy: .public)s
                stderr: \(result.error, privacy: .public)
                """
            )
            throw AnalyzeServiceError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.error
            )
        }
        do {
            let report = try decoder.decode(AnalyzeReport.self, from: result.output)
            Self.logger.info(
                """
                analyze ok — elapsed=\(String(format: "%.2f", elapsed), privacy: .public)s \
                outputBytes=\(result.output.utf8.count, privacy: .public) \
                entries=\(report.entries.count, privacy: .public) \
                totalBytes=\(report.totalSize, privacy: .public)
                """
            )
            return report
        } catch {
            Self.logger.error(
                "analyze decode failed — error=\(String(describing: error), privacy: .public) outputBytes=\(result.output.utf8.count, privacy: .public)"
            )
            throw error
        }
    }
}
