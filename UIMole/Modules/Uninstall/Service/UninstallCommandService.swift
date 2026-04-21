import Foundation

struct UninstallCommandOutcome: Sendable, Equatable {
    let exitCode: Int32
    let output: String
    let error: String

    var isSuccess: Bool { exitCode == 0 }
}

protocol UninstallCommandService: Sendable {
    func uninstall(appNames: [String], dryRun: Bool) async throws -> UninstallCommandOutcome
}

/// Invokes the user-installed `mo uninstall` CLI (Homebrew or manual install).
/// We don't ship mole's shell scripts; this service expects the `mo` binary on
/// PATH. Homebrew's default install locations are forced into PATH so the call
/// succeeds when the app is launched from Finder without an inherited shell.
final class MoleUninstallCommandService: UninstallCommandService {

    private let executor: CommandExecuting

    init(executor: CommandExecuting) {
        self.executor = executor
    }

    func uninstall(appNames: [String], dryRun: Bool) async throws -> UninstallCommandOutcome {
        guard !appNames.isEmpty else {
            return UninstallCommandOutcome(exitCode: 0, output: "", error: "")
        }

        let quoted = appNames.map(Self.shellQuote).joined(separator: " ")
        var script = "echo y | mo uninstall \(quoted)"
        if dryRun {
            script += " --dry-run"
        }

        let result = try await executor.execute(
            "/bin/sh",
            arguments: ["-c", script],
            currentDirectory: nil,
            environment: Self.makeEnvironment()
        )
        return UninstallCommandOutcome(
            exitCode: result.exitCode,
            output: result.output,
            error: result.error
        )
    }

    /// Inherit the parent process environment so HOME/USER/etc. survive — mole's
    /// shell libs run with `set -u` and bail on missing HOME. Only PATH is
    /// overridden, hardened with the usual Homebrew prefixes so `mo` resolves
    /// when UIMole is launched outside a login shell.
    static func makeEnvironment(
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = baseEnvironment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["MOLE_NO_COLOR"] = "1"
        return env
    }

    /// Escape a string for use as a single shell argument (single-quoted).
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
