import Foundation
import Observation

@MainActor
protocol SettingsViewModel: AnyObject, Observable {
    var appName: String { get }
    var versionString: String { get }
}

@MainActor
@Observable
final class DefaultSettingsViewModel: SettingsViewModel {

    let appName: String
    let versionString: String

    init(bundle: Bundle = .main) {
        self.appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UIMole"
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        self.versionString = "\(short) (\(build))"
    }
}
