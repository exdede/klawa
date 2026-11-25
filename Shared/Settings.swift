/// Keys in `AppGroup.defaults`, written by the app (layout, haptics) and the keyboard (languageMode).
enum SettingsKey {
    static let layout = "layout"
    static let haptics = "haptics"
    static let languageMode = "languageMode"
    static let autocorrect = "autocorrect"
    static let snippets = "snippets"
    static let keyPopup = "keyPopup"
    static let customWords = "customWords"
}

/// The owner's own words (names) with exact capitals: suggested, never autocorrected away.
enum CustomWords {
    static func load() -> [String] { AppGroup.defaults?.stringArray(forKey: SettingsKey.customWords) ?? [] }
    static func save(_ words: [String]) { AppGroup.defaults?.set(words, forKey: SettingsKey.customWords) }
}
