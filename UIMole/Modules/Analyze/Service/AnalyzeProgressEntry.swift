import Foundation

/// Snapshot of a single directory that `mole analyze` has finished scanning.
struct AnalyzeProgressEntry: Sendable, Equatable, Identifiable {

    let path: String
    let size: Int64

    var id: String { path }
}

extension AnalyzeProgressEntry {

    /// Maps the absolute paths mole writes to `overview_sizes.json` to the
    /// friendly labels it uses in the final report. The table lives here (and
    /// not in the view) so presentation code stays path-agnostic.
    static func displayName(for path: String) -> String {
        if let label = labels[path] {
            return label
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private static let home: String = {
        FileManager.default.homeDirectoryForCurrentUser.path
    }()

    private static let labels: [String: String] = {
        let home = AnalyzeProgressEntry.home
        return [
            home: "Home",
            "\(home)/Library": "App Library",
            "/Applications": "Applications",
            "/Library": "System Library",
            "\(home)/Library/Logs": "System Logs",
            "\(home)/Library/Caches/Homebrew": "Homebrew Cache",
            "\(home)/Library/Developer/Xcode/DerivedData": "Xcode DerivedData",
            "\(home)/Library/Developer/CoreSimulator/Devices": "Xcode Simulators",
            "\(home)/Library/Developer/Xcode/Archives": "Xcode Archives",
            "\(home)/Library/Caches/JetBrains": "JetBrains Cache",
            "\(home)/Library/Containers/com.docker.docker/Data": "Docker Data",
            "\(home)/Library/Caches/pip": "pip Cache",
            "\(home)/.gradle/caches": "Gradle Cache",
            "\(home)/Downloads": "Old Downloads (90d+)"
        ]
    }()
}
