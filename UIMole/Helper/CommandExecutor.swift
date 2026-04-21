import Foundation

enum CommandExecutorError: Error, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
}

final class CommandExecutor: CommandExecuting {

    init() {}

    func execute(
        _ executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String]?
    ) async throws -> CommandResult {
        let executableURL = try resolveExecutableURL(executable)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            if let currentDirectory {
                process.currentDirectoryURL = currentDirectory
            }
            if let environment {
                process.environment = environment
            }

            process.terminationHandler = { proc in
                let outputData = (try? outputPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errorData = (try? errorPipe.fileHandleForReading.readToEnd()) ?? Data()
                let result = CommandResult(
                    output: String(data: outputData, encoding: .utf8) ?? "",
                    error: String(data: errorData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(
                    throwing: CommandExecutorError.launchFailed(error.localizedDescription)
                )
            }
        }
    }

    private func resolveExecutableURL(_ executable: String) throws -> URL {
        if executable.hasPrefix("/") {
            let url = URL(fileURLWithPath: executable)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw CommandExecutorError.executableNotFound(executable)
            }
            return url
        }

        let searchPaths = ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin"]
        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        throw CommandExecutorError.executableNotFound(executable)
    }
}
