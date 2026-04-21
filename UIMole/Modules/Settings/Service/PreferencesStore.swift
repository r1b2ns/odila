import Foundation

/// Persistent user preferences shared across modules. Concrete implementations
/// must be thread-safe — UserDefaults is.
protocol PreferencesStoring: Sendable {
    var safeModeEnabled: Bool { get set }
}

/// UserDefaults-backed store. Registers defaults on init so fresh installs
/// start with the expected values even before the user touches Settings.
final class UserDefaultsPreferencesStore: PreferencesStoring, @unchecked Sendable {

    enum Key {
        static let safeModeEnabled = "settings.safeModeEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.safeModeEnabled: true])
    }

    var safeModeEnabled: Bool {
        get { defaults.bool(forKey: Key.safeModeEnabled) }
        set { defaults.set(newValue, forKey: Key.safeModeEnabled) }
    }
}
