public struct EmojiGroup: Equatable {
    public let name: String
    public let emojis: [String]

    public init(name: String, emojis: [String]) {
        self.name = name
        self.emojis = emojis
    }
}

public enum EmojiCatalog {
    /// Parses `Name<TAB>emoji emoji ...` lines (see scripts/gen-emoji.py).
    public static func parse(_ text: String) -> [EmojiGroup] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return EmojiGroup(name: String(parts[0]), emojis: parts[1].split(separator: " ").map(String.init))
        }
    }

    /// Most recent first, no duplicates, at most `limit`.
    public static func addRecent(_ emoji: String, to recents: [String], limit: Int = 32) -> [String] {
        Array(([emoji] + recents.filter { $0 != emoji }).prefix(limit))
    }
}
