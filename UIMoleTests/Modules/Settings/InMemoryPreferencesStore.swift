import Foundation
@testable import UIMole

final class InMemoryPreferencesStore: PreferencesStoring, @unchecked Sendable {

    var safeModeEnabled: Bool

    init(safeModeEnabled: Bool = true) {
        self.safeModeEnabled = safeModeEnabled
    }
}
