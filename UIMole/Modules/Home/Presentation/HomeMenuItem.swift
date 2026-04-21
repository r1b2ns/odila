import Foundation

struct HomeMenuItem: Identifiable, Hashable, Sendable {
    let id: HomeDestination
    let icon: String
    let title: String
    let subtitle: String
    let isEnabled: Bool
}
