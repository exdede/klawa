import Foundation

/// What the owner typed, kept only in the keyboard's own container: how often each word was used
/// (new words count as known after two uses) and which word tends to follow which.
public struct UserWords: Codable, Equatable {
    public private(set) var counts: [String: Int] = [:]
    public private(set) var next: [String: [String: Int]] = [:]

    public init() {}

    public mutating func learn(_ word: String, after previous: String?, times: Int = 1) {
        let w = word.lowercased()
        guard !w.isEmpty else { return }
        counts[w, default: 0] += times
        if let p = previous?.lowercased(), !p.isEmpty { next[p, default: [:]][w, default: 0] += times }
        if counts.count > 3000 { counts = Self.keepTop(counts, 2000) }
        if next.count > 3000 { next = next.filter { $0.value.values.reduce(0, +) > 1 } }
    }

    public func knows(_ word: String) -> Bool { (counts[word.lowercased()] ?? 0) >= 2 }

    private static func keepTop(_ d: [String: Int], _ n: Int) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: d.sorted { $0.value > $1.value }.prefix(n).map { ($0.key, $0.value) })
    }
}

/// Likely next words from subtitles (scripts/gen-next.py); `<s>` = start of a sentence.
public struct NextWords {
    private var table: [LanguageMode: [String: [String]]] = [.pl: [:], .en: [:]]

    /// Parses `p|e<TAB>previous<TAB>next next ...` lines.
    public init(text: String) {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 3 else { continue }
            table[parts[0] == "e" ? .en : .pl]![String(parts[1])] = parts[2].split(separator: " ").map(String.init)
        }
    }

    /// After `previous` (nil = sentence start), the typing language first.
    public func after(_ previous: String?, language: LanguageMode) -> [String] {
        let key = previous?.lowercased() ?? "<s>"
        return (table[language]?[key] ?? []) + (table[language.next]?[key] ?? [])
    }
}

public struct Suggestions: Equatable {
    /// Best first, never the typed word itself.
    public var words: [String] = []
    /// Replaces the typed word on space or punctuation.
    public var autocorrect: String?

    public init(words: [String] = [], autocorrect: String? = nil) {
        self.words = words
        self.autocorrect = autocorrect
    }
}

public struct Suggester {
    public let lexicon: Lexicon
    public var neighbors: [Character: Set<Character>]
    public var next: NextWords?

    public init(lexicon: Lexicon, layout: LayoutName) {
        self.lexicon = lexicon
        neighbors = letterNeighbors(layout)
    }

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    /// `custom`: the owner's own words with exact capitals (names); always known, suggested first.
    public func suggest(typed: String, previous: String?, language: LanguageMode, user: UserWords,
                        custom: [String] = []) -> Suggestions {
        let learnedNext = previous.flatMap { user.next[$0.lowercased()] } ?? [:]
        let corpusNext = next?.after(previous, language: language) ?? []
        guard !typed.isEmpty else {
            var words = learnedNext.sorted { $0.value > $1.value }.prefix(3).map(\.key)
            for w in corpusNext where words.count < 3 && !words.contains(where: { $0.lowercased() == w.lowercased() }) {
                words.append(w)
            }
            return Suggestions(words: words)
        }
        let likelyHere = Set(corpusNext).union(learnedNext.keys)
        let lower = typed.lowercased()
        let key = Lexicon.fold(typed)
        let typedHasPolish = lower != key && lower.contains { "ąćęłńóśźż".contains($0) }
        var best: [String: (score: Float, correction: Bool)] = [:]
        func add(_ word: String, _ score: Float, correction: Bool) {
            if let old = best[word], old.score >= score { return }
            best[word] = (score, correction)
        }
        func base(_ e: Lexicon.Entry) -> Float {
            let used = Float(user.counts[e.word.lowercased()] ?? 0)
            return e.logp + (e.language == language ? 0 : -1.1) + 0.7 * log(1 + used)
                + (likelyHere.contains(e.word) || likelyHere.contains(e.word.lowercased()) ? 2 : 0) // fits after the previous word
        }

        // same keys typed (any Polish letters) or a longer word starting with them
        let range = lexicon.range(prefix: key)
        if range.count < 40_000 {
            for (folded, e) in lexicon.items(in: range) {
                var score = base(e)
                if typedHasPolish && !e.word.lowercased().hasPrefix(lower) { score -= 2 } // typed ó on purpose
                if folded.count == key.count {
                    add(e.word, score, correction: true)
                } else {
                    add(e.word, score - 1, correction: false)
                }
            }
        }
        // the owner's own words rank like very common words
        var customByFold: [String: String] = [:]
        for c in custom {
            let f = Lexicon.fold(c)
            customByFold[f] = c
            if f.hasPrefix(key) { add(c, f.count == key.count ? -5 : -6, correction: f.count == key.count) }
        }
        // one typo away (missing, extra, swapped or wrong letter)
        if key.count >= 2 {
            for (edit, cost) in edits(of: key) {
                for e in lexicon.exact(edit) { add(e.word, base(e) - cost, correction: key.count >= 3) }
                if let c = customByFold[edit] { add(c, -5 - cost, correction: key.count >= 3) }
            }
        }
        // words the owner taught the keyboard
        for (w, n) in user.counts where n >= 2 && Lexicon.fold(w).hasPrefix(key) && !lexicon.contains(w) {
            add(w, log(Float(n)) - 12 - (Lexicon.fold(w).count == key.count ? 0 : 1), correction: false)
        }

        best[typed] = nil
        best[lower] = nil
        let ranked = best.sorted { $0.value.score > $1.value.score || ($0.value.score == $1.value.score && $0.key < $1.key) }
        var result = Suggestions(words: ranked.prefix(3).map { Self.matchCase($0.key, typed) })
        result.autocorrect = autocorrection(typed: typed, lower: lower, language: language, user: user, custom: custom,
                                            top: ranked.first { $0.value.correction && $0.value.score > -17 }?.key)
        if let a = result.autocorrect, let i = result.words.firstIndex(of: a), i > 0 {
            result.words.remove(at: i)
            result.words.insert(a, at: 0)
        } else if let a = result.autocorrect, !result.words.contains(a) {
            result.words = [a] + result.words.prefix(2)
        }
        return result
    }

    private func autocorrection(typed: String, lower: String, language: LanguageMode, user: UserWords,
                                custom: [String], top: String?) -> String? {
        guard typed.dropFirst().allSatisfy({ !$0.isUppercase }) else { return nil } // CAPS = on purpose
        if let own = custom.first(where: { $0.lowercased() == lower }) { return own == typed ? nil : own } // "ewa" -> "Ewa"
        if lexicon.contains(typed) || user.knows(typed) {
            // English "i" -> "I" style case fixes only when typing English
            guard language == .en, lower == typed,
                  let fixed = lexicon.exact(Lexicon.fold(typed)).first(where: { $0.language == .en && $0.word != lower && $0.word.lowercased() == lower })
            else { return nil }
            return fixed.word
        }
        guard typed.count >= 2 else { return nil }
        return top.map { Self.matchCase($0, typed) }
    }

    /// Every spelling one edit away, with its cost (a neighbor key is a cheaper mistake).
    func edits(of key: String) -> [(String, Float)] {
        let chars = Array(key)
        var out: [(String, Float)] = []
        func s(_ a: [Character]) -> String { String(a) }
        for i in chars.indices {
            var d = chars; d.remove(at: i); out.append((s(d), 4.5))
            if i + 1 < chars.count {
                var t = chars; t.swapAt(i, i + 1); out.append((s(t), 3.5))
            }
            for c in Self.alphabet where c != chars[i] {
                var r = chars; r[i] = c
                out.append((s(r), neighbors[chars[i]]?.contains(c) == true ? 2.5 : 5))
            }
        }
        for i in 0...chars.count {
            for c in Self.alphabet {
                var n = chars; n.insert(c, at: i); out.append((s(n), 4.5))
            }
        }
        return out
    }

    /// "Zolw" -> "Żółw"; "I" stays "I".
    static func matchCase(_ word: String, _ typed: String) -> String {
        guard let first = typed.first, first.isUppercase else { return word }
        return word.prefix(1).uppercased() + word.dropFirst()
    }
}
