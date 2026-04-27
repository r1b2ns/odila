import SwiftUI

@main
struct UIMoleApp: App {

    @State private var path = NavigationPath()
    @State private var showOnboarding: Bool = !UserDefaultsPreferencesStore().onboardingCompleted

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                HomeFactory.make()
                    .navigationDestination(for: HomeDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingFactory.make {
                    showOnboarding = false
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .status:
            StatusFactory.make()
        case .analyze:
            AnalyzeFactory.make()
        case .uninstall:
            UninstallFactory.make()
        case .settings:
            SettingsFactory.make()
        case .clean, .optimize:
            ContentUnavailableView(
                "Coming soon",
                systemImage: "hammer",
                description: Text("This feature isn't available yet.")
            )
        }
    }
}
