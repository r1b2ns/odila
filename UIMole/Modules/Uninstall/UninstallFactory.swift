import SwiftUI

enum UninstallFactory {

    @MainActor
    static func make() -> some View {
        let executor = CommandExecutor()
        let listService = DefaultInstalledAppsService()
        let uninstallService = MoleUninstallCommandService(executor: executor)
        let preferences = UserDefaultsPreferencesStore()
        let viewModel = DefaultUninstallViewModel(
            service: listService,
            uninstallService: uninstallService,
            preferences: preferences
        )
        return UninstallView(viewModel: viewModel)
    }
}
