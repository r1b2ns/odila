import Foundation
import Observation

@MainActor
protocol StatusViewModel: AnyObject, Observable {
    var snapshot: StatusSnapshot? { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }

    func start()
    func stop()
}

@MainActor
@Observable
final class DefaultStatusViewModel: StatusViewModel {

    static let pollingInterval: Duration = .seconds(5)

    private(set) var snapshot: StatusSnapshot?
    private(set) var errorMessage: String?
    private(set) var isLoading: Bool = false

    private let service: StatusService
    private var pollingTask: Task<Void, Never>?

    init(service: StatusService) {
        self.service = service
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: Self.pollingInterval)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func refresh() async {
        if snapshot == nil {
            isLoading = true
        }
        do {
            let snap = try await service.fetchSnapshot()
            snapshot = snap
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
        isLoading = false
    }
}
