import Foundation

/// Polish + English word list sorted by folded spelling (see scripts/gen-words.py).
/// Answers: which words start with a prefix, which words a typo was meant to be, and
/// how likely each next letter is (for the invisible key resizing).
public final class Lexicon {
    public struct Entry: Equatable {
        public let word: String
        public let language: LanguageMode
        /// ln(relative frequency within its language)
        public let logp: Float
    }

    private let folded: [String]
    private let entries: [Entry]
    /// cumulative relative frequency per language, `count + 1` long, in folded order
    private let cumulative: [LanguageMode: [Double]]

    /// Parses `word<TAB>p|e<TAB>count` lines (already sorted by folded spelling; re-sorted if not).
    public init(text: String) {
        var folded: [String] = [], words: [String] = [], languages: [LanguageMode] = [], counts: [Double] = []
        var totals: [LanguageMode: Double] = [.pl: 0, .en: 0]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 3, let count = Double(parts[2]), count > 0 else { continue }
            let language: LanguageMode = parts[1] == "e" ? .en : .pl
            let word = String(parts[0])
            folded.append(Lexicon.fold(word))
            words.append(word)
            languages.append(language)
            counts.append(count)
            totals[language]! += count
        }
        var order = Array(folded.indices)
        if !zip(folded, folded.dropFirst()).allSatisfy({ $0 <= $1 }) {
            order.sort { folded[$0] < folded[$1] }
        }
        self.folded = order.map { folded[$0] }
        entries = order.map { Entry(word: words[$0], language: languages[$0], logp: Float(log(counts[$0] / totals[languages[$0]]!))) }
        var cumulative: [LanguageMode: [Double]] = [:]
        for language in LanguageMode.allCases {
            var sum = 0.0
            var c = [0.0]
            c.reserveCapacity(order.count + 1)
            for i in order {
                if languages[i] == language { sum += counts[i] / totals[language]! }
                c.append(sum)
            }
            cumulative[language] = c
        }
        self.cumulative = cumulative
    }

    public var count: Int { entries.count }

    /// Lowercase, Polish letters to base letters, apostrophes removed: what the keys spell.
    public static func fold(_ s: String) -> String {
        var out = ""
        for c in s.lowercased() {
            switch c {
            case "ą": out.append("a")
            case "ć": out.append("c")
            case "ę": out.append("e")
            case "ł": out.append("l")
            case "ń": out.append("n")
            case "ó": out.append("o")
            case "ś": out.append("s")
            case "ź", "ż": out.append("z")
            case "'", "’": break
            default: out.append(c)
            }
        }
        return out
    }

    private func lowerBound(_ key: String) -> Int {
        var lo = 0, hi = folded.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if folded[mid] < key { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Entries whose folded spelling starts with `prefix` (already folded).
    func range(prefix: String) -> Range<Int> {
        lowerBound(prefix)..<lowerBound(prefix + "\u{10FFFF}")
    }

    /// Entries whose folded spelling is exactly `key`.
    func exact(_ key: String) -> ArraySlice<Entry> {
        let lo = lowerBound(key)
        var hi = lo
        while hi < folded.count, folded[hi] == key { hi += 1 }
        return entries[lo..<hi]
    }

    func items(in range: Range<Int>) -> Zip2Sequence<ArraySlice<String>, ArraySlice<Entry>> {
        zip(folded[range], entries[range])
    }

    /// True when the word exists as typed (case-insensitive, Polish letters must match).
    public func contains(_ word: String) -> Bool {
        let lower = word.lowercased()
        return exact(Lexicon.fold(word)).contains { $0.word.lowercased() == lower }
    }

    /// How often words continue with each of `letters` after the folded `prefix`, weighted by language.
    /// nil when no word starts with the prefix (a name, slang): then there is nothing to bias.
    public func nextLetterMass(prefix: String, letters: [String], weights: [LanguageMode: Double]) -> [Double]? {
        func mass(_ p: String) -> Double {
            let r = range(prefix: p)
            return weights.reduce(0.0) { sum, w in sum + w.value * (cumulative[w.key]![r.upperBound] - cumulative[w.key]![r.lowerBound]) }
        }
        let masses = letters.map { mass(prefix + $0) }
        return masses.contains { $0 > 0 } ? masses : nil
    }
}
