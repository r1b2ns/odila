import Foundation
import os

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

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "uninstall.command"
    )

    private let executor: CommandExecuting

    init(executor: CommandExecuting) {
        self.executor = executor
    }

    func uninstall(appNames: [String], dryRun: Bool) async throws -> UninstallCommandOutcome {
        guard !appNames.isEmpty else {
            return UninstallCommandOutcome(exitCode: 0, output: "", error: "")
        }

        let quoted = appNames.map(Self.shellQuote).joined(separator: " ")
        var moCommand = "echo y | mo uninstall \(quoted)"
        if dryRun {
            moCommand += " --dry-run"
        }

        Self.logger.info(
            "Running mo uninstall — apps=\(appNames, privacy: .public) dryRun=\(dryRun, privacy: .public)"
        )

        do {
            let result: CommandResult
            if dryRun {
                result = try await runUnprivileged(moCommand: moCommand)
            } else {
                result = try await runAsAdmin(moCommand: moCommand)
            }
            return finalize(result: result)
        } catch {
            Self.logger.error(
                "mo uninstall threw — error=\(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    private func runUnprivileged(moCommand: String) async throws -> CommandResult {
        try await executor.execute(
            "/bin/sh",
            arguments: ["-c", moCommand],
            currentDirectory: nil,
            environment: Self.makeEnvironment()
        )
    }

    /// Wraps the `mo` invocation in an AppleScript `do shell script ... with
    /// administrator privileges`. macOS shows the native auth dialog (Touch ID
    /// or password) and runs the script as root without needing a controlling
    /// TTY — this is what unblocks mole's interactive sudo prompts that fail
    /// with `/dev/tty: Device not configured` when launched from a GUI app.
    private func runAsAdmin(moCommand: String) async throws -> CommandResult {
        // Root's environment loses Homebrew on PATH and uses /var/root as HOME.
        // Re-export the user's HOME/USER so mole touches the right Library
        // directories when scanning leftovers.
        let path = "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin\""
        let home = "export HOME=\(Self.shellQuote(NSHomeDirectory()))"
        let user = "export USER=\(Self.shellQuote(NSUserName()))"
        // Merge stderr into stdout so mole's `Admin access denied` line and
        // any sudo diagnostics both reach `do shell script`'s captured output.
        let shellScript = "\(path); \(home); \(user); \(moCommand) 2>&1"
        let appleScript = "do shell script \(Self.appleScriptQuote(shellScript)) with administrator privileges"

        return try await executor.execute(
            "/usr/bin/osascript",
            arguments: ["-e", appleScript],
            currentDirectory: nil,
            environment: nil
        )
    }

    private func finalize(result: CommandResult) -> UninstallCommandOutcome {
        // osascript reports a cancelled auth dialog as exit 1 with `(-128)` in
        // stderr. Translate it to a friendlier message so the UI doesn't show
        // raw AppleScript noise.
        if result.exitCode != 0 && Self.isUserCancellation(stderr: result.error) {
            Self.logger.info("mo uninstall cancelled by user at auth dialog")
            return UninstallCommandOutcome(
                exitCode: result.exitCode,
                output: "",
                error: "Authorization cancelled."
            )
        }

        if result.exitCode == 0 {
            Self.logger.info(
                "mo uninstall ok — exit=0 outputBytes=\(result.output.utf8.count, privacy: .public)"
            )
        } else {
            Self.logger.error(
                """
                mo uninstall failed — exit=\(result.exitCode, privacy: .public)
                stdout: \(result.output, privacy: .public)
                stderr: \(result.error, privacy: .public)
                """
            )
        }
        return UninstallCommandOutcome(
            exitCode: result.exitCode,
            output: result.output,
            error: result.error
        )
    }

    private static func isUserCancellation(stderr: String) -> Bool {
        stderr.contains("(-128)") || stderr.localizedCaseInsensitiveContains("user canceled")
    }

    /// AppleScript double-quoted string: escape backslashes first, then quotes.
    static func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
