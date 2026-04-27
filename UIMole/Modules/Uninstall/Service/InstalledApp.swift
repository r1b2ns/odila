import Foundation

struct InstalledApp: Sendable, Equatable, Identifiable {

    let name: String
    let bundleIdentifier: String
    let version: String
    let url: URL
    let sizeBytes: Int64

    var id: URL { url }

    init(
        name: String,
        bundleIdentifier: String,
        version: String,
        url: URL,
        sizeBytes: Int64 = 0
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.url = url
        self.sizeBytes = sizeBytes
    }
}
