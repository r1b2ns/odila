import Foundation
import Testing
@testable import UIMole

/// Live integration test for the real `MoleUninstallCommandService`. Runs
/// mole as the regular user (mole pops its own native auth dialog when
/// sudo is actually needed). Disabled by default — to run:
///
///   xcodebuild test -project UIMole.xcodeproj -scheme UIMole \
///     -destination 'platform=macOS' \
///     -only-testing:UIMoleTests/LiveUninstallTests/<methodName>
@Suite("Live uninstall (manual)")
struct LiveUninstallTests {

    /// Dry-run against an actual app. Should complete in seconds without
    /// any auth prompt — the dry-run path doesn't escalate.
    @Test(.timeLimit(.minutes(1)))
    func dryRunRustRoverViaProductionService() async throws {
        let appPath = NSHomeDirectory() + "/Applications/RustRover.app"
        guard FileManager.default.fileExists(atPath: appPath) else {
            print("[live] RustRover.app not found at \(appPath) — skipping")
            return
        }

        let executor = CommandExecutor()
        let sut = MoleUninstallCommandService(executor: executor)

        let start = Date()
        let outcome = try await sut.uninstall(appNames: ["RustRover"], dryRun: true)
        let elapsed = Date().timeIntervalSince(start)

        print("[live] dry-run elapsed=\(String(format: "%.2f", elapsed))s exit=\(outcome.exitCode)")
        print("[live] stdout (truncated):\n\(String(outcome.output.prefix(2000)))")
        print("[live] stderr:\n\(outcome.error.isEmpty ? "(empty)" : outcome.error)")

        #expect(outcome.isSuccess)
        #expect(outcome.output.contains("RustRover"))
    }
}
