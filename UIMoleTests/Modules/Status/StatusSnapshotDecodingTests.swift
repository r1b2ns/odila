import Foundation
import Testing
@testable import UIMole

struct StatusSnapshotDecodingTests {

    @Test
    func decodesLiveMoleStatusOutput() async throws {
        let statusURL = try #require(
            Bundle.main.url(forResource: "status", withExtension: nil, subdirectory: "mole"),
            "embedded mole/status binary not found in app bundle"
        )

        let executor = CommandExecutor()
        let decoder = CommandOutputJSONDecoder()

        let result = try await executor.execute(statusURL.path, arguments: ["-json"])
        #expect(result.isSuccess)

        let snapshot = try decoder.decode(StatusSnapshot.self, from: result.output)

        #expect(!snapshot.host.isEmpty)
        #expect(!snapshot.platform.isEmpty)
        #expect(snapshot.cpu.coreCount > 0)
        #expect(snapshot.memory.total > 0)
    }
}
