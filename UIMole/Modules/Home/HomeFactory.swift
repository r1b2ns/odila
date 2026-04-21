import SwiftUI

enum HomeFactory {

    @MainActor
    static func make() -> some View {
        let viewModel = DefaultHomeViewModel()
        return HomeView(viewModel: viewModel)
    }
}
