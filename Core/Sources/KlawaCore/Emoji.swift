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
    private let byKeyword: [String: [String]]
    private let byName: [String: [String]]

    /// Parses `emoji<TAB>keyword|keyword...[<TAB>name|name]` lines (already folded).
    public init(text: String) {
        var byName: [String: [String]] = [:]
        items = text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { return nil }
            if parts.count > 2 {
                for n in Set(parts[2].split(separator: "|").map(String.init)) { byName[n, default: []].append(String(parts[0])) }
            }
            return (String(parts[0]), parts[1].split(separator: "|").map(String.init))
        }
        var byKeyword: [String: [String]] = [:]
        for item in items {
            for k in item.keywords { byKeyword[k, default: []].append(item.emoji) }
        }
        self.byKeyword = byKeyword
        self.byName = byName
    }

    /// Emoji whose keyword is exactly this word ("kot" -> 🐱 🐈), for the suggestion bar.
    /// Emoji named exactly this word come first: "pizza" -> 🍕 before 🍄‍🟫 (keyword "pizza").
    public func exact(_ word: String) -> [String] {
        let w = Lexicon.fold(word)
        let named = byName[w] ?? []
        return named + (byKeyword[w] ?? []).filter { !named.contains($0) }
    }

    /// Every query word must start a keyword word ("czer ser" finds ❤️). Exact name, then exact keyword first.
    public func search(_ query: String, limit: Int = 60) -> [String] {
        let q = Lexicon.fold(query).trimmingCharacters(in: .whitespaces)
        let tokens = q.split(separator: " ")
        guard !tokens.isEmpty else { return [] }
        var scored: [(Int, Int, String)] = []
        for (i, item) in items.enumerated() {
            let words = item.keywords.flatMap { $0.split(whereSeparator: { " -:,".contains($0) }) }
            guard tokens.allSatisfy({ t in words.contains { $0.hasPrefix(t) } }) else { continue }
            let rank = byName[q]?.contains(item.emoji) == true ? 0
                : item.keywords.contains(q) ? 1 : (item.keywords.contains { $0.hasPrefix(q) } ? 2 : 3)
            scored.append((rank, i, item.emoji))
        }
        return scored.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(limit).map { $0.2 }
    }
}
