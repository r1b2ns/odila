import Foundation
import Testing
@testable import UIMole

struct InstalledAppsServiceTests {

    @Test
    func enumeratesAppsFromSearchDirectory() async throws {
        let root = try makeTempRoot()
        try writeFakeApp(
            at: root.appendingPathComponent("Alpha.app"),
            bundleID: "com.example.alpha",
            name: "Alpha",
            version: "1.2.3"
        )
        try writeFakeApp(
            at: root.appendingPathComponent("Beta.app"),
            bundleID: "com.example.beta",
            name: "Beta",
            version: "4.5"
        )

        let sut = DefaultInstalledAppsService(searchURLs: [root])
        let apps = try await sut.fetchApps()

        #expect(apps.map(\.name) == ["Alpha", "Beta"]) // sorted alphabetically
        #expect(apps[0].bundleIdentifier == "com.example.alpha")
        #expect(apps[0].version == "1.2.3")
        #expect(apps[1].bundleIdentifier == "com.example.beta")
    }

    @Test
    func descendsOneLevelIntoSubfolders() async throws {
        let root = try makeTempRoot()
        let utilities = root.appendingPathComponent("Utilities", isDirectory: true)
        try FileManager.default.createDirectory(at: utilities, withIntermediateDirectories: true)
        try writeFakeApp(
            at: utilities.appendingPathComponent("DiskUtility.app"),
            bundleID: "com.example.diskutil",
            name: "Disk Utility",
            version: "22.0"
        )

        let sut = DefaultInstalledAppsService(searchURLs: [root])
        let apps = try await sut.fetchApps()

        #expect(apps.map(\.bundleIdentifier) == ["com.example.diskutil"])
    }

    @Test
    func dedupesAppsSharingABundleIdentifier() async throws {
        let firstRoot = try makeTempRoot()
        let secondRoot = try makeTempRoot()
        try writeFakeApp(
            at: firstRoot.appendingPathComponent("Alpha.app"),
            bundleID: "com.example.alpha",
            name: "Alpha",
            version: "1"
        )
        try writeFakeApp(
            at: secondRoot.appendingPathComponent("Alpha.app"),
            bundleID: "com.example.alpha",
            name: "Alpha",
            version: "2"
        )

        let sut = DefaultInstalledAppsService(searchURLs: [firstRoot, secondRoot])
        let apps = try await sut.fetchApps()

        #expect(apps.count == 1)
        #expect(apps.first?.version == "1") // first-seen wins
    }

    @Test
    func fallsBackToFolderNameWhenInfoPlistOmitsName() async throws {
        let root = try makeTempRoot()
        try writeFakeApp(
            at: root.appendingPathComponent("Weird.app"),
            bundleID: "com.example.weird",
            name: nil,
            version: ""
        )

        let sut = DefaultInstalledAppsService(searchURLs: [root])
        let apps = try await sut.fetchApps()

        #expect(apps.first?.name == "Weird")
    }

    @Test
    func skipsDirectoriesWithoutInfoPlist() async throws {
        let root = try makeTempRoot()
        let malformed = root.appendingPathComponent("Broken.app", isDirectory: true)
        try FileManager.default.createDirectory(at: malformed, withIntermediateDirectories: true)

        let sut = DefaultInstalledAppsService(searchURLs: [root])
        let apps = try await sut.fetchApps()

        #expect(apps.isEmpty)
    }

    @Test
    func missingSearchPathReturnsEmpty() async throws {
        let missing = URL(fileURLWithPath: "/tmp/uimole-tests-nonexistent-\(UUID().uuidString)")
        let sut = DefaultInstalledAppsService(searchURLs: [missing])
        let apps = try await sut.fetchApps()
        #expect(apps.isEmpty)
    }

    // MARK: - Helpers

    private func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uimole-apps-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFakeApp(
        at bundleURL: URL,
        bundleID: String,
        name: String?,
        version: String
    ) throws {
        let contentsDir = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        var plist: [String: Any] = ["CFBundleIdentifier": bundleID]
        if let name {
            plist["CFBundleName"] = name
        }
        if !version.isEmpty {
            plist["CFBundleShortVersionString"] = version
        }

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contentsDir.appendingPathComponent("Info.plist"))
    }
}
