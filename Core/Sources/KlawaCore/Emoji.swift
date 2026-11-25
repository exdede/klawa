import Foundation

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

/// Finds emoji by Polish or English words (CLDR keywords, see scripts/gen-emoji.py).
public struct EmojiSearch {
    private let items: [(emoji: String, keywords: [String])]

    /// Parses `emoji<TAB>keyword|keyword...` lines (keywords already folded).
    public init(text: String) {
        items = text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), parts[1].split(separator: "|").map(String.init))
        }
    }

    /// Every query word must start a keyword word ("czer ser" finds ❤️). Exact keyword first.
    public func search(_ query: String, limit: Int = 60) -> [String] {
        let q = Lexicon.fold(query).trimmingCharacters(in: .whitespaces)
        let tokens = q.split(separator: " ")
        guard !tokens.isEmpty else { return [] }
        var scored: [(Int, Int, String)] = []
        for (i, item) in items.enumerated() {
            let words = item.keywords.flatMap { $0.split(whereSeparator: { " -:,".contains($0) }) }
            guard tokens.allSatisfy({ t in words.contains { $0.hasPrefix(t) } }) else { continue }
            let rank = item.keywords.contains(q) ? 0 : (item.keywords.contains { $0.hasPrefix(q) } ? 1 : 2)
            scored.append((rank, i, item.emoji))
        }
        return scored.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(limit).map { $0.2 }
    }
}
