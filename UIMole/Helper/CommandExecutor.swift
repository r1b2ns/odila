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

            // Drain both pipes asynchronously while the child runs. Without this
            // a chatty child (e.g. `mo uninstall` printing every leftover path)
            // fills the ~64KB pipe buffer, blocks on its next write, and never
            // exits — so `terminationHandler` never fires and the call hangs.
            let outputBuffer = LockedData()
            let errorBuffer = LockedData()
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    outputBuffer.append(chunk)
                }
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    errorBuffer.append(chunk)
                }
            }

            process.terminationHandler = { proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                if let trailing = try? outputPipe.fileHandleForReading.readToEnd() {
                    outputBuffer.append(trailing)
                }
                if let trailing = try? errorPipe.fileHandleForReading.readToEnd() {
                    errorBuffer.append(trailing)
                }
                let outputData = outputBuffer.snapshot
                let errorData = errorBuffer.snapshot
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
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
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

private final class LockedData: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var snapshot: Data {
        lock.lock()
        let copy = data
        lock.unlock()
        return copy
    }
}
