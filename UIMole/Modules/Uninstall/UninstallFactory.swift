import SwiftUI

enum UninstallFactory {

    @MainActor
    static func make() -> some View {
        let service = DefaultInstalledAppsService()
        let viewModel = DefaultUninstallViewModel(service: service)
        return UninstallView(viewModel: viewModel)
    }
}
