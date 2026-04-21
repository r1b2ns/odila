import Foundation
import Testing
@testable import UIMole

@MainActor
struct SettingsViewModelTests {

    @Test
    func readsAppNameAndVersionFromMainBundle() {
        let sut = DefaultSettingsViewModel(bundle: .main)

        #expect(!sut.appName.isEmpty)
        #expect(sut.versionString.contains("("))
        #expect(sut.versionString.contains(")"))
    }

    @Test
    func fallsBackWhenBundleKeysAreMissing() throws {
        let emptyBundle = try makeEmptyBundle()
        let sut = DefaultSettingsViewModel(bundle: emptyBundle)

        #expect(sut.appName == "UIMole")
        #expect(sut.versionString == "0.0 (0)")
    }

    // MARK: - Helpers

    private func makeEmptyBundle() throws -> Bundle {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIMole-empty-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        let plistURL = tempURL.appendingPathComponent("Info.plist")
        let emptyPlist: [String: Any] = [:]
        let data = try PropertyListSerialization.data(
            fromPropertyList: emptyPlist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)

        guard let bundle = Bundle(url: tempURL) else {
            struct BundleCreationFailed: Error {}
            throw BundleCreationFailed()
        }
        return bundle
    }
}
