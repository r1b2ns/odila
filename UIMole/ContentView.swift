import SwiftUI

struct ContentView: View {

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeFactory.make()
                .navigationDestination(for: HomeDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .status:
            StatusFactory.make()
        case .clean, .uninstall, .optimize, .analyze:
            ContentUnavailableView(
                "Coming soon",
                systemImage: "hammer",
                description: Text("This feature isn't available yet.")
            )
        }
    }
}
