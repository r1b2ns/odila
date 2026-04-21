import Foundation
import Testing
@testable import UIMole

struct AnalyzeProgressSourceTests {

    @Test
    func parseDecodesOverviewFile() throws {
        let url = try writeTempOverview(json: #"""
        {
            "/Applications": { "size": 22727389184, "updated": "2026-04-21T00:00:00Z" },
            "/Users/me":     { "size": 112994968035, "updated": "2026-04-21T00:00:01Z" }
        }
        """#)

        let entries = try #require(AnalyzeProgressSource.parse(fileAt: url))
        #expect(entries.count == 2)
        let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
        #expect(byPath["/Applications"]?.size == 22_727_389_184)
        #expect(byPath["/Users/me"]?.size == 112_994_968_035)
    }

    @Test
    func parseReturnsNilForMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/mole-progress-tests-nonexistent-\(UUID().uuidString).json")
        #expect(AnalyzeProgressSource.parse(fileAt: url) == nil)
    }

    @Test
    func parseReturnsNilForMalformedJSON() throws {
        let url = try writeTempOverview(json: "{not json}")
        #expect(AnalyzeProgressSource.parse(fileAt: url) == nil)
    }

    @Test
    func streamEmitsSnapshotWheneverFileChanges() async throws {
        let url = try writeTempOverview(json: #"""
        { "/a": { "size": 10, "updated": "2026-04-21T00:00:00Z" } }
        """#)
        let sut = AnalyzeProgressSource(
            overviewURL: url,
            pollInterval: .milliseconds(50)
        )

        // Collect a few snapshots in a background task, then update the file.
        let collectorTask = Task<[[AnalyzeProgressEntry]], Never> {
            var collected: [[AnalyzeProgressEntry]] = []
            for await snapshot in sut.stream() {
                collected.append(snapshot)
                if collected.count >= 2 { break }
            }
            return collected
        }

        // Give the collector a moment to receive the initial emission,
        // then mutate the file to force a second emission.
        try await Task.sleep(for: .milliseconds(200))
        try #"""
        {
            "/a": { "size": 10, "updated": "2026-04-21T00:00:00Z" },
            "/b": { "size": 20, "updated": "2026-04-21T00:00:01Z" }
        }
        """#.write(to: url, atomically: true, encoding: .utf8)

        // Wait for the collector to finish, bounded by a timeout.
        let snapshots = try await withThrowingTaskGroup(of: [[AnalyzeProgressEntry]]?.self) { group in
            group.addTask { await collectorTask.value }
            group.addTask {
                try await Task.sleep(for: .seconds(3))
                return nil
            }
            defer { group.cancelAll() }
            if let result = try await group.next(), let unwrapped = result {
                return unwrapped
            }
            collectorTask.cancel()
            throw TimeoutError()
        }

        #expect(snapshots.count == 2)
        #expect(snapshots.first?.map(\.path) == ["/a"])
        #expect(Set(snapshots.last?.map(\.path) ?? []) == ["/a", "/b"])
    }

    // MARK: - Helpers

    private func writeTempOverview(json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mole-progress-\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private struct TimeoutError: Error {}
}
