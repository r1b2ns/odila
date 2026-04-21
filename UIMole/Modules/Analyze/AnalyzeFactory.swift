import SwiftUI

enum AnalyzeFactory {

    @MainActor
    static func make() -> some View {
        AnalyzeFactoryView()
    }
}

private struct AnalyzeFactoryView: View {

    var body: some View {
        do {
            let binaryURL = try MoleBinaryLocator.url(for: "analyze")
            let service = DefaultAnalyzeService(
                executor: CommandExecutor(),
                decoder: CommandOutputJSONDecoder(),
                binaryURL: binaryURL
            )
            let viewModel = DefaultAnalyzeViewModel(service: service)
            return AnyView(AnalyzeView(viewModel: viewModel))
        } catch {
            return AnyView(
                ContentUnavailableView(
                    "Mole analyze binary not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(describing: error))
                )
            )
        }
    }
}
