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

/// Invokes the bundled `uninstall-mo.sh` helper which wraps the user-installed
/// `mo uninstall` CLI. The script encapsulates PATH/HOME hardening and the
/// double-fork detach pattern needed when running under `osascript do shell
/// script with administrator privileges` (mole forks long-lived Dock/
/// LaunchServices helpers that would otherwise hold the osascript pipe open).
final class MoleUninstallCommandService: UninstallCommandService {

    private static let logger = Logger(
        subsystem: "br.com.UIMole",
        category: "uninstall.command"
    )

    private let executor: CommandExecuting
    private let scriptURL: URL

    init(
        executor: CommandExecuting,
        scriptURL: URL = MoleUninstallCommandService.bundledScriptURL()
    ) {
        self.executor = executor
        self.scriptURL = scriptURL
    }

    /// Resolves `Resources/Scripts/uninstall-mo.sh` from the app bundle. Falls
    /// back to a path relative to the source tree so unit tests running
    /// against a freshly-built test bundle still find the script.
    static func bundledScriptURL() -> URL {
        if let url = Bundle.main.url(
            forResource: "uninstall-mo",
            withExtension: "sh"
        ) {
            return url
        }
        // Test host's Bundle.main is the test runner, which doesn't carry the
        // app's resources. Walk up to the SRCROOT-relative copy.
        let fallback = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Service
            .deletingLastPathComponent() // Uninstall
            .deletingLastPathComponent() // Modules
            .deletingLastPathComponent() // UIMole
            .appendingPathComponent("Resources/Scripts/uninstall-mo.sh")
        return fallback
    }

    func uninstall(appNames: [String], dryRun: Bool) async throws -> UninstallCommandOutcome {
        guard !appNames.isEmpty else {
            return UninstallCommandOutcome(exitCode: 0, output: "", error: "")
        }

        Self.logger.info(
            "Running mo uninstall — apps=\(appNames, privacy: .public) dryRun=\(dryRun, privacy: .public) script=\(self.scriptURL.path, privacy: .public)"
        )

        do {
            // We run mole as the regular user for both dry-run and real
            // uninstall. Running mole as root via `osascript do shell script
            // with administrator privileges` causes mole to hang at
            // "Finalizing list..." (mole bug). For ~/Applications/ items
            // owned by the user, mole proceeds directly. For /Applications/
            // items needing sudo, mole pops its own native auth dialog via
            // `osascript display dialog` and uses `sudo -S` internally.
            var args = [scriptURL.path]
            if dryRun {
                args.append("--dry-run")
            }
            args.append(contentsOf: appNames)
            let result = try await executor.execute(
                "/bin/bash",
                arguments: args,
                currentDirectory: nil,
                environment: Self.makeEnvironment()
            )
            return finalize(result: result)
        } catch {
            Self.logger.error(
                "mo uninstall threw — error=\(String(describing: error), privacy: .public)"
            )
            throw error
        }
    }

    private func finalize(result: CommandResult) -> UninstallCommandOutcome {
        // mole's own GUI sudo dialog uses osascript internally and surfaces
        // a cancelled auth as exit 1 with `(-128)` somewhere in stderr.
        // Translate it to a friendlier message.
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
