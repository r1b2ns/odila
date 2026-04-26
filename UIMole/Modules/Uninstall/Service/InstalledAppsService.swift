import Foundation

protocol InstalledAppsService: Sendable {
    func fetchApps() async throws -> [InstalledApp]
}

/// Walks the standard macOS application directories and extracts metadata from
/// each `.app` bundle's `Info.plist`. Mole's `mo uninstall` ultimately scans the
/// same locations — doing it natively avoids shelling out to a non-JSON shell
/// script and keeps the module testable.
final class DefaultInstalledAppsService: InstalledAppsService {

    private let searchURLs: [URL]

    init(searchURLs: [URL] = DefaultInstalledAppsService.defaultSearchURLs) {
        self.searchURLs = searchURLs
    }

    static var defaultSearchURLs: [URL] {
        let fileManager = FileManager.default
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    func fetchApps() async throws -> [InstalledApp] {
        let urls = searchURLs
        return try await Task.detached(priority: .userInitiated) {
            var seen = Set<String>()
            var results: [InstalledApp] = []
            for base in urls {
                for app in Self.enumerate(under: base) {
                    let key = app.bundleIdentifier.isEmpty
                        ? app.url.path
                        : app.bundleIdentifier
                    if seen.insert(key).inserted {
                        results.append(app)
                    }
                }
            }
            return results.sorted { lhs, rhs in
                if lhs.sizeBytes != rhs.sizeBytes {
                    return lhs.sizeBytes > rhs.sizeBytes
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }.value
    }

    private static func enumerate(under baseURL: URL) -> [InstalledApp] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseURL.path) else { return [] }

        guard let topLevel = try? fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [InstalledApp] = []
        for url in topLevel {
            if url.pathExtension == "app" {
                if let app = parseApp(at: url) {
                    results.append(app)
                }
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                // One level of nesting — covers folders like /Applications/Utilities.
                let nested = (try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )) ?? []
                for candidate in nested where candidate.pathExtension == "app" {
                    if let app = parseApp(at: candidate) {
                        results.append(app)
                    }
                }
            }
        }
        return results
    }

    private static func parseApp(at url: URL) -> InstalledApp? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        guard
            let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let plist = raw as? [String: Any]
        else { return nil }

        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? fallbackName
        let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
        let version = (plist["CFBundleShortVersionString"] as? String)
            ?? (plist["CFBundleVersion"] as? String)
            ?? ""

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            url: url,
            sizeBytes: bundleSize(at: url)
        )
    }

    private static func bundleSize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
            total &+= Int64(size)
        }
        return total
    }
}
