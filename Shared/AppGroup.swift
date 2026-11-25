import Foundation

/// App Group shared by the app and the keyboard extension.
enum AppGroup {
    static let fallbackID = "group.com.exdede.klawa"

    /// Installers (iloader, SideStore) register the group under a new ID (e.g. with the team ID appended).
    /// The real one is in this bundle's embedded provisioning profile; every signed bundle has its own copy.
    static let id: String = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let first = (entitlements["com.apple.security.application-groups"] as? [String])?.first
        else { return fallbackID }
        return first
    }()

    /// nil when this build is not entitled to the group (signing dropped it, or no Full Access in the keyboard).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    static var defaults: UserDefaults? {
        containerURL == nil ? nil : UserDefaults(suiteName: id)
    }
}
