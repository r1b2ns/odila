import SwiftUI

enum SettingsFactory {

    @MainActor
    static func make() -> some View {
        let viewModel = DefaultSettingsViewModel()
        return SettingsView(viewModel: viewModel)
    }
}
