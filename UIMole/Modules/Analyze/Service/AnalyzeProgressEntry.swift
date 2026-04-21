import Foundation

/// Snapshot of a single directory that `mole analyze` has finished scanning.
struct AnalyzeProgressEntry: Sendable, Equatable, Identifiable {

    let path: String
    let size: Int64

    var id: String { path }
}

/// A directory that mole is known to include in its disk analysis. The list
/// drives both the order and the labels shown while the scan is in progress
/// (so pending rows can show a real name, not just "pending..").
struct AnalyzeCategory: Sendable, Equatable, Identifiable {

    let path: String
    let displayName: String

    var id: String { path }
}

extension AnalyzeCategory {

    /// Canonical order mole reports on the terminal TUI. Any path mole adds in
    /// the future that is not in this list will still appear in the UI — just
    /// after the known ones during the scan, and in the final JSON order once
    /// the scan completes.
    static let known: [AnalyzeCategory] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            AnalyzeCategory(path: home, displayName: "Home"),
            AnalyzeCategory(path: "\(home)/Library", displayName: "App Library"),
            AnalyzeCategory(path: "/Applications", displayName: "Applications"),
            AnalyzeCategory(path: "/Library", displayName: "System Library"),
            AnalyzeCategory(path: "\(home)/Library/Logs", displayName: "System Logs"),
            AnalyzeCategory(
                path: "\(home)/Library/Caches/Homebrew",
                displayName: "Homebrew Cache"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Developer/Xcode/DerivedData",
                displayName: "Xcode DerivedData"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Developer/CoreSimulator/Devices",
                displayName: "Xcode Simulators"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Developer/Xcode/Archives",
                displayName: "Xcode Archives"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Caches/JetBrains",
                displayName: "JetBrains Cache"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Containers/com.docker.docker/Data",
                displayName: "Docker Data"
            ),
            AnalyzeCategory(
                path: "\(home)/Library/Caches/pip",
                displayName: "pip Cache"
            ),
            AnalyzeCategory(
                path: "\(home)/.gradle/caches",
                displayName: "Gradle Cache"
            )
        ]
    }()

    private static let byPath: [String: AnalyzeCategory] = {
        Dictionary(uniqueKeysWithValues: known.map { ($0.path, $0) })
    }()

    /// Friendly label for a given absolute path, falling back to the last path
    /// component when mole reports a directory outside the known list.
    static func displayName(for path: String) -> String {
        if let category = byPath[path] {
            return category.displayName
        }
        let basename = URL(fileURLWithPath: path).lastPathComponent
        return basename.isEmpty ? path : basename
    }
}
