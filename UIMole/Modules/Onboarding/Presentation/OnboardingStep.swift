import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case about
    case dependencies

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome to Mole"
        case .about: return "About UIMole"
        case .dependencies: return "Requirements"
        }
    }
}
