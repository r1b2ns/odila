import Foundation
import Observation

@MainActor
protocol HomeViewModel: AnyObject, Observable {
    var menuItems: [HomeMenuItem] { get }
}

@MainActor
@Observable
final class DefaultHomeViewModel: HomeViewModel {

    let menuItems: [HomeMenuItem] = [
        HomeMenuItem(
            id: .clean,
            icon: "sparkles",
            title: "Clean",
            subtitle: "Free up disk space by removing junk",
            isEnabled: false
        ),
        HomeMenuItem(
            id: .uninstall,
            icon: "minus.circle",
            title: "Uninstall",
            subtitle: "Remove apps and their leftovers",
            isEnabled: false
        ),
        HomeMenuItem(
            id: .optimize,
            icon: "speedometer",
            title: "Optimize",
            subtitle: "Tune your Mac for better performance",
            isEnabled: false
        ),
        HomeMenuItem(
            id: .analyze,
            icon: "chart.bar.xaxis",
            title: "Analyze",
            subtitle: "Inspect disk usage in detail",
            isEnabled: true
        ),
        HomeMenuItem(
            id: .status,
            icon: "gauge.with.dots.needle.67percent",
            title: "Status",
            subtitle: "Live system health and metrics",
            isEnabled: true
        ),
        HomeMenuItem(
            id: .settings,
            icon: "gearshape",
            title: "Settings",
            subtitle: "Preferences and app information",
            isEnabled: true
        )
    ]
}
