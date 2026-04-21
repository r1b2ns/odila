//
//  CommandExecutorTests.swift
//  UIMoleTests
//

import Foundation
import Testing
@testable import UIMole

struct CommandExecutorTests {

    @Test
    func executesEchoAndReturnsStdout() async throws {
        let sut = CommandExecutor()
        let result = try await sut.execute("/bin/echo", arguments: ["hello", "world"])

        #expect(result.isSuccess)
        #expect(result.exitCode == 0)
        #expect(result.output == "hello world\n")
        #expect(result.error.isEmpty)
    }

    @Test
    func resolvesExecutableByNameFromStandardPaths() async throws {
        let sut = CommandExecutor()
        let result = try await sut.execute("echo", arguments: ["ok"])

        #expect(result.isSuccess)
        #expect(result.output == "ok\n")
    }

    @Test
    func returnsNonZeroExitCodeForFailingCommand() async throws {
        let sut = CommandExecutor()
        let result = try await sut.execute("/usr/bin/false")

        #expect(result.isSuccess == false)
        #expect(result.exitCode != 0)
    }

    @Test
    func capturesStandardError() async throws {
        let sut = CommandExecutor()
        let result = try await sut.execute(
            "/bin/sh",
            arguments: ["-c", "echo oops 1>&2; exit 3"]
        )

        #expect(result.exitCode == 3)
        #expect(result.error == "oops\n")
        #expect(result.output.isEmpty)
    }

    @Test
    func throwsWhenAbsolutePathDoesNotExist() async throws {
        let sut = CommandExecutor()
        await #expect(throws: CommandExecutorError.self) {
            _ = try await sut.execute("/usr/bin/definitely-not-a-real-binary-xyz")
        }
    }

    @Test
    func throwsWhenExecutableNameCannotBeResolved() async throws {
        let sut = CommandExecutor()
        await #expect(throws: CommandExecutorError.self) {
            _ = try await sut.execute("definitely-not-a-real-binary-xyz")
        }
    }

    @Test
    func honoursCurrentDirectory() async throws {
        let sut = CommandExecutor()
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .resolvingSymlinksInPath()

        let result = try await sut.execute(
            "/bin/pwd",
            arguments: [],
            currentDirectory: tempDir,
            environment: nil
        )

        #expect(result.isSuccess)
        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == tempDir.path)
    }

    @Test
    func honoursCustomEnvironment() async throws {
        let sut = CommandExecutor()
        let result = try await sut.execute(
            "/bin/sh",
            arguments: ["-c", "printf %s \"$UIMOLE_TEST_VAR\""],
            currentDirectory: nil,
            environment: ["UIMOLE_TEST_VAR": "mole-value", "PATH": "/usr/bin:/bin"]
        )

        #expect(result.isSuccess)
        #expect(result.output == "mole-value")
    }

    @Test
    func isSuccessReflectsExitCode() {
        #expect(CommandResult(output: "", error: "", exitCode: 0).isSuccess)
        #expect(CommandResult(output: "", error: "", exitCode: 1).isSuccess == false)
        #expect(CommandResult(output: "", error: "", exitCode: -1).isSuccess == false)
    }
}
