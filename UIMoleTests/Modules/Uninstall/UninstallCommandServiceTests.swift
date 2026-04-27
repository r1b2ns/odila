import Foundation
import Testing
@testable import UIMole

struct UninstallCommandServiceTests {

    private actor RecordingExecutor: CommandExecuting {
        struct Invocation: Sendable, Equatable {
            let executable: String
            let arguments: [String]
            let environment: [String: String]?
        }

        private(set) var invocations: [Invocation] = []
        private let output: String
        private let error: String
        private let exitCode: Int32

        init(output: String = "", error: String = "", exitCode: Int32 = 0) {
            self.output = output
            self.error = error
            self.exitCode = exitCode
        }

        func execute(
            _ executable: String,
            arguments: [String],
            currentDirectory: URL?,
            environment: [String: String]?
        ) async throws -> CommandResult {
            invocations.append(
                Invocation(
                    executable: executable,
                    arguments: arguments,
                    environment: environment
                )
            )
            return CommandResult(output: output, error: error, exitCode: exitCode)
        }
    }

    @Test
    func dryRunInvokesBundledScriptWithDryRunFlag() async throws {
        let executor = RecordingExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        _ = try await sut.uninstall(
            appNames: ["Google Chrome", "VS Code"],
            dryRun: true
        )

        let invocations = await executor.invocations
        #expect(invocations.count == 1)
        let first = try #require(invocations.first)
        #expect(first.executable == "/bin/bash")
        #expect(first.arguments[0].hasSuffix("uninstall-mo.sh"))
        #expect(Array(first.arguments.dropFirst()) == ["--dry-run", "Google Chrome", "VS Code"])
        #expect(first.environment?["PATH"]?.contains("/opt/homebrew/bin") == true)
    }

    @Test
    func realUninstallRunsAsUserNotRoot() async throws {
        let executor = RecordingExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        _ = try await sut.uninstall(appNames: ["Alpha"], dryRun: false)

        let invocations = await executor.invocations
        let first = try #require(invocations.first)
        // mole hangs at "Finalizing list..." when run as root via
        // `osascript do shell script with administrator privileges`. We
        // run it as the user instead — mole pops its own native auth
        // dialog when sudo is actually needed.
        #expect(first.executable == "/bin/bash")
        #expect(first.executable != "/usr/bin/osascript")
        #expect(first.arguments[0].hasSuffix("uninstall-mo.sh"))
        #expect(Array(first.arguments.dropFirst()) == ["Alpha"])
        // Real uninstall must NOT pass --dry-run.
        #expect(first.arguments.contains("--dry-run") == false)
    }

    @Test
    func translatesUserCancellationFromOsascript() async throws {
        let executor = RecordingExecutor(
            error: "execution error: User canceled. (-128)",
            exitCode: 1
        )
        let sut = MoleUninstallCommandService(executor: executor)

        let outcome = try await sut.uninstall(appNames: ["Alpha"], dryRun: false)

        #expect(outcome.isSuccess == false)
        #expect(outcome.error.localizedCaseInsensitiveContains("cancelled"))
    }

    @Test
    func appleScriptQuoteEscapesBackslashesAndQuotes() {
        // Inputs from `shellQuote` may contain backslash-escaped quotes.
        let quoted = MoleUninstallCommandService.appleScriptQuote(#"It's \"weird\""#)
        // Backslash-escape backslashes first, then double quotes.
        #expect(quoted == #""It's \\\"weird\\\"""#)
    }

    @Test
    func emptyListIsNoOp() async throws {
        let executor = RecordingExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        let outcome = try await sut.uninstall(appNames: [], dryRun: false)

        #expect(outcome.isSuccess)
        let invocations = await executor.invocations
        #expect(invocations.isEmpty)
    }

    @Test
    func escapesSingleQuotesInAppName() {
        let quoted = MoleUninstallCommandService.shellQuote("It's nice")
        #expect(quoted == "'It'\\''s nice'")
    }

    @Test
    func preservesParentEnvironmentWhileOverridingPath() {
        let env = MoleUninstallCommandService.makeEnvironment(
            baseEnvironment: [
                "HOME": "/Users/tester",
                "USER": "tester",
                "PATH": "/bogus"
            ]
        )

        // mole's shell libs run with `set -u` — HOME must survive.
        #expect(env["HOME"] == "/Users/tester")
        #expect(env["USER"] == "tester")
        // PATH is replaced with hardened Homebrew-aware defaults.
        #expect(env["PATH"]?.contains("/opt/homebrew/bin") == true)
        #expect(env["PATH"] != "/bogus")
    }

    @Test
    func surfacesFailureExitCode() async throws {
        let executor = RecordingExecutor(exitCode: 127)
        let sut = MoleUninstallCommandService(executor: executor)

        let outcome = try await sut.uninstall(appNames: ["Alpha"], dryRun: false)

        #expect(outcome.isSuccess == false)
        #expect(outcome.exitCode == 127)
    }
}
