import Foundation

/// App Group shared by the app and the keyboard extension.
enum AppGroup {
    static let fallbackID = "group.com.exdede.klawa"

    /// SideStore re-registers groups under new IDs and lists them in Info.plist `ALTAppGroups`.
    /// An extension may only have that key in the containing app's Info.plist (two levels up from the .appex).
    static let id: String = {
        let containingApp = Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
        for bundle in [Bundle.main, containingApp].compactMap({ $0 }) {
            if let first = (bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String])?.first {
                return first
            }
        }
        return fallbackID
    }()

    /// nil when this build is not entitled to the group (signing dropped it, or no Full Access in the keyboard).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static var defaults: UserDefaults? {
        containerURL == nil ? nil : UserDefaults(suiteName: id)
    }
}
