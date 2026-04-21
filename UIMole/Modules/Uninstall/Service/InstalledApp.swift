import Foundation

struct InstalledApp: Sendable, Equatable, Identifiable {

    let name: String
    let bundleIdentifier: String
    let version: String
    let url: URL

    var id: URL { url }
}
