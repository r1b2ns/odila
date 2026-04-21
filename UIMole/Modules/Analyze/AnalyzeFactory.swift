import SwiftUI

enum AnalyzeFactory {

    /// Process-wide purger so the cache is only wiped once per UIMole launch,
    /// no matter how many times the Analyze screen is opened.
    nonisolated(unsafe) private static let sharedCachePurger: AnalyzeCachePurging =
        AnalyzeCachePurger(executor: CommandExecutor())

    @MainActor
    static func make() -> some View {
        AnalyzeFactoryView(cachePurger: sharedCachePurger)
    }
}

private struct AnalyzeFactoryView: View {

    let cachePurger: AnalyzeCachePurging

    var body: some View {
        do {
            let binaryURL = try MoleBinaryLocator.url(for: "analyze")
            let service = DefaultAnalyzeService(
                executor: CommandExecutor(),
                decoder: CommandOutputJSONDecoder(),
                binaryURL: binaryURL
            )
            let viewModel = DefaultAnalyzeViewModel(
                service: service,
                cachePurger: cachePurger,
                progressSource: AnalyzeProgressSource()
            )
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
