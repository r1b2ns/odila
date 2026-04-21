import Foundation
@testable import UIMole

final class MockAnalyzeProgressSource: AnalyzeProgressSourcing, @unchecked Sendable {

    private let snapshots: [[AnalyzeProgressEntry]]
    private let interval: Duration

    init(
        snapshots: [[AnalyzeProgressEntry]],
        interval: Duration = .milliseconds(20)
    ) {
        self.snapshots = snapshots
        self.interval = interval
    }

    func stream() -> AsyncStream<[AnalyzeProgressEntry]> {
        let snapshots = snapshots
        let interval = interval
        return AsyncStream { continuation in
            let task = Task {
                for snapshot in snapshots {
                    if Task.isCancelled { break }
                    continuation.yield(snapshot)
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
