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
        private let exitCode: Int32

        init(output: String = "", exitCode: Int32 = 0) {
            self.output = output
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
            return CommandResult(output: output, error: "", exitCode: exitCode)
        }
    }

    @Test
    func buildsShellCommandWithQuotedNamesAndDryRun() async throws {
        let executor = RecordingExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        _ = try await sut.uninstall(
            appNames: ["Google Chrome", "VS Code"],
            dryRun: true
        )

        let invocations = await executor.invocations
        #expect(invocations.count == 1)
        let first = try #require(invocations.first)
        #expect(first.executable == "/bin/sh")
        #expect(first.arguments[0] == "-c")
        #expect(first.arguments[1] == "echo y | mo uninstall 'Google Chrome' 'VS Code' --dry-run")
        // Hardened PATH so `mo` resolves from Finder launches.
        #expect(first.environment?["PATH"]?.contains("/opt/homebrew/bin") == true)
    }

    @Test
    func omitsDryRunFlagWhenDisabled() async throws {
        let executor = RecordingExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        _ = try await sut.uninstall(appNames: ["Alpha"], dryRun: false)

        let invocations = await executor.invocations
        let script = invocations.first?.arguments[1] ?? ""
        #expect(script == "echo y | mo uninstall 'Alpha'")
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
