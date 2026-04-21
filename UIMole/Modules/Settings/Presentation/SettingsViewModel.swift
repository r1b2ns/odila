import Foundation
import Observation

@MainActor
protocol SettingsViewModel: AnyObject, Observable {
    var appName: String { get }
    var versionString: String { get }
    var safeModeEnabled: Bool { get }

    func setSafeMode(enabled: Bool)
}

@MainActor
@Observable
final class DefaultSettingsViewModel: SettingsViewModel {

    let appName: String
    let versionString: String
    private(set) var safeModeEnabled: Bool

    private var preferences: PreferencesStoring

    init(
        bundle: Bundle = .main,
        preferences: PreferencesStoring = UserDefaultsPreferencesStore()
    ) {
        self.appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UIMole"
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        self.versionString = "\(short) (\(build))"
        self.preferences = preferences
        self.safeModeEnabled = preferences.safeModeEnabled
    }

    func setSafeMode(enabled: Bool) {
        safeModeEnabled = enabled
        preferences.safeModeEnabled = enabled
    }
}
