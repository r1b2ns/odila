import Foundation
import Testing
@testable import UIMole

struct PreferencesStoreTests {

    @Test
    func safeModeDefaultsToTrueOnFreshInstall() throws {
        let defaults = try makeIsolatedDefaults()
        let sut = UserDefaultsPreferencesStore(defaults: defaults)

        #expect(sut.safeModeEnabled == true)
    }

    @Test
    func persistsSafeModeBetweenInstances() throws {
        let defaults = try makeIsolatedDefaults()

        var first = UserDefaultsPreferencesStore(defaults: defaults)
        first.safeModeEnabled = false

        let second = UserDefaultsPreferencesStore(defaults: defaults)
        #expect(second.safeModeEnabled == false)
    }

    @Test
    func updatesReflectImmediately() throws {
        let defaults = try makeIsolatedDefaults()
        var sut = UserDefaultsPreferencesStore(defaults: defaults)

        sut.safeModeEnabled = false
        #expect(sut.safeModeEnabled == false)
        sut.safeModeEnabled = true
        #expect(sut.safeModeEnabled == true)
    }

    // MARK: - Helpers

    private func makeIsolatedDefaults() throws -> UserDefaults {
        let suite = "UIMoleTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            struct SuiteCreationFailed: Error {}
            throw SuiteCreationFailed()
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
