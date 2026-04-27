import Foundation
import Observation

@MainActor
protocol OnboardingViewModel: AnyObject, Observable {
    var currentStep: OnboardingStep { get }
    var brewStatus: DependencyStatus { get }
    var moleStatus: DependencyStatus { get }
    var isCheckingDependencies: Bool { get }
    var lastError: String? { get }

    var canAdvance: Bool { get }
    var canFinish: Bool { get }
    var isLastStep: Bool { get }

    func advance()
    func goBack()
    func refreshDependencies() async
    func installBrew()
    func installMole()
    func finish()
}

@MainActor
@Observable
final class DefaultOnboardingViewModel: OnboardingViewModel {

    private(set) var currentStep: OnboardingStep = .welcome
    private(set) var brewStatus: DependencyStatus = .unknown
    private(set) var moleStatus: DependencyStatus = .unknown
    private(set) var isCheckingDependencies: Bool = false
    private(set) var lastError: String?

    private var preferences: PreferencesStoring
    private let environment: DependencyEnvironmentService
    private let onFinish: () -> Void

    init(
        preferences: PreferencesStoring,
        environment: DependencyEnvironmentService,
        onFinish: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.environment = environment
        self.onFinish = onFinish
    }

    var isLastStep: Bool { currentStep == .dependencies }

    var canAdvance: Bool { !isLastStep }

    var canFinish: Bool {
        if case .installed = brewStatus, case .installed = moleStatus {
            return true
        }
        return false
    }

    func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        if currentStep == .dependencies {
            Task { await refreshDependencies() }
        }
    }

    func goBack() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    func refreshDependencies() async {
        guard !isCheckingDependencies else { return }
        isCheckingDependencies = true
        lastError = nil
        brewStatus = .checking
        moleStatus = .checking

        let brew = await environment.checkBrew()
        brewStatus = brew

        if case .installed = brew {
            moleStatus = await environment.checkMole()
        } else {
            moleStatus = .missing
        }

        isCheckingDependencies = false
    }

    func installBrew() {
        do {
            try environment.openInstallBrewInTerminal()
        } catch {
            lastError = "Couldn't open Terminal to install Homebrew."
        }
    }

    func installMole() {
        do {
            try environment.openInstallMoleInTerminal()
        } catch {
            lastError = "Couldn't open Terminal to install Mole."
        }
    }

    func finish() {
        preferences.onboardingCompleted = true
        onFinish()
    }
}
