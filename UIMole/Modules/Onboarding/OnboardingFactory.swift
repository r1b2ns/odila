import SwiftUI

enum OnboardingFactory {

    @MainActor
    static func make(onFinish: @escaping () -> Void) -> some View {
        let viewModel = DefaultOnboardingViewModel(
            preferences: UserDefaultsPreferencesStore(),
            environment: DefaultDependencyEnvironmentService(),
            onFinish: onFinish
        )
        return OnboardingView(viewModel: viewModel)
    }
}
