import Foundation
import Testing
@testable import UIMole

struct AnalyzeCachePurgerTests {

    private actor RecordingExecutor: CommandExecuting {
        struct Invocation: Sendable, Equatable {
            let executable: String
            let arguments: [String]
        }

        private(set) var invocations: [Invocation] = []

        func execute(
            _ executable: String,
            arguments: [String],
            currentDirectory: URL?,
            environment: [String: String]?
        ) async throws -> CommandResult {
            invocations.append(Invocation(executable: executable, arguments: arguments))
            return CommandResult(output: "", error: "", exitCode: 0)
        }
    }

    @Test
    func runsRmRfOnFirstCall() async {
        let executor = RecordingExecutor()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-mole-cache", isDirectory: true)
        let sut = AnalyzeCachePurger(executor: executor, cacheURL: cacheURL)

        await sut.purgeIfNeeded()

        let invocations = await executor.invocations
        #expect(invocations.count == 1)
        #expect(invocations.first?.executable == "/bin/rm")
        #expect(invocations.first?.arguments == ["-rf", cacheURL.path])
    }

    @Test
    func doesNotRunAgainOnSubsequentCalls() async {
        let executor = RecordingExecutor()
        let cacheURL = URL(fileURLWithPath: "/tmp/test-mole-cache", isDirectory: true)
        let sut = AnalyzeCachePurger(executor: executor, cacheURL: cacheURL)

        await sut.purgeIfNeeded()
        await sut.purgeIfNeeded()
        await sut.purgeIfNeeded()

        let invocations = await executor.invocations
        #expect(invocations.count == 1)
    }
}
