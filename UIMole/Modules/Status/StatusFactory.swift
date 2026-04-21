import SwiftUI

enum StatusFactory {

    @MainActor
    static func make() -> some View {
        StatusFactoryView()
    }
}

private struct StatusFactoryView: View {

    var body: some View {
        do {
            let binaryURL = try MoleBinaryLocator.url(for: "status")
            let service = DefaultStatusService(
                executor: CommandExecutor(),
                decoder: CommandOutputJSONDecoder(),
                binaryURL: binaryURL
            )
            let viewModel = DefaultStatusViewModel(service: service)
            return AnyView(StatusView(viewModel: viewModel))
        } catch {
            return AnyView(
                ContentUnavailableView(
                    "Mole status binary not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(describing: error))
                )
            )
        }
    }
}
