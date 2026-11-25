public enum LayoutName: String, CaseIterable {
    case qwerty, colemak
}

public enum Page {
    case letters, numbers, symbols
}

public enum KeyKind: Equatable {
    case character(String)
    case shift, backspace, pageNumbers, pageSymbols, pageLetters, language, emoji, globe, space, returnKey
}

public struct Key: Equatable {
    public let kind: KeyKind
    /// Relative width; a letter key is 1.0 and a full row is 10.0.
    public let width: Double
    /// Long-press options, first one preselected.
    public let alternates: [String]
    /// Small label in the key corner (top-row digits).
    public let hint: String?

    public init(_ kind: KeyKind, width: Double = 1, alternates: [String] = [], hint: String? = nil) {
        self.kind = kind
        self.width = width
        self.alternates = alternates
        self.hint = hint
    }
}

private let letterRows: [LayoutName: [String]] = [
    .qwerty: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    .colemak: ["qwfpgjluy;", "arstdhneio", "zxcvbkm"],
]

private let polishLetters = Set("ąćęłńóśźż")

private let accents: [String: [String]] = [
    "a": ["ą", "á", "à", "â", "ä", "ã", "å", "æ"],
    "c": ["ć", "č", "ç"],
    "e": ["ę", "é", "è", "ê", "ë", "ė"],
    "l": ["ł"],
    "n": ["ń", "ñ"],
    "o": ["ó", "ö", "ô", "ò", "õ", "ø", "œ"],
    "s": ["ś", "š", "ß"],
    "z": ["ż", "ź", "ž"],
    "u": ["ü", "ú", "û", "ù"],
    "i": ["í", "ï", "î", "ì"],
    "y": ["ý", "ÿ"],
]

private let symbolAlternates: [String: [String]] = [
    ".": [",", "?", "!", "'", "\"", "-", ":", ";", "(", ")", "@", "/", "…", "&", "%", "#"],
    "-": ["–", "—", "•"],
    "\"": ["„", "”", "«", "»"],
    "'": ["‘", "’"],
    "zł": ["$", "€", "£", "¥"],
    "0": ["°"],
    "?": ["¿"],
    "!": ["¡"],
    "&": ["§"],
    ";": [":"],
]

private func chars(_ items: [String], width: Double = 1) -> [Key] {
    items.map { Key(.character($0), width: width, alternates: symbolAlternates[$0] ?? []) }
}

private func split(_ s: String) -> [String] { s.map(String.init) }

/// The four rows of keys for a layout and page. Every row fits in 10.0 width units.
public func keyRows(_ layout: LayoutName, page: Page) -> [[Key]] {
    let bottom: [Key] = [
        Key(page == .letters ? .pageNumbers : .pageLetters, width: 1.2),
        Key(.language, width: 1.1),
        Key(.emoji, width: 1.1),
        Key(.space, width: 3.6),
    ] + chars(["."]) + [Key(.returnKey, width: 2)]

    switch page {
    case .letters:
        let rows = letterRows[layout]!
        let top = split(rows[0]).enumerated().map { i, ch in
            let digit = String((i + 1) % 10)
            let accented = accents[ch] ?? symbolAlternates[ch] ?? []
            // Polish letter first (release = ó for o), then the digit, then other accents.
            let polish = accented.filter { polishLetters.contains(Character($0)) }
            let others = accented.filter { !polishLetters.contains(Character($0)) }
            return Key(.character(ch), alternates: polish + [digit] + others, hint: digit)
        }
        let letters = { (s: String) in split(s).map { Key(.character($0), alternates: accents[$0] ?? []) } }
        return [top, letters(rows[1]), [Key(.shift, width: 1.5)] + letters(rows[2]) + [Key(.backspace, width: 1.5)], bottom]
    case .numbers:
        return [
            chars(split("1234567890")),
            chars(["-", "/", ":", ";", "(", ")", "zł", "&", "@", "\""]),
            [Key(.pageSymbols, width: 1.5)] + chars([".", ",", "?", "!", "'"], width: 1.4) + [Key(.backspace, width: 1.5)],
            bottom,
        ]
    case .symbols:
        return [
            chars(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]),
            chars(["_", "\\", "|", "~", "<", ">", "€", "$", "£", "•"]),
            [Key(.pageNumbers, width: 1.5)] + chars([".", ",", "?", "!", "'"], width: 1.4) + [Key(.backspace, width: 1.5)],
            bottom,
        ]
    }
}

/// Letters next to each letter on the layout (same row and the rows above/below), for typo costs.
public func letterNeighbors(_ layout: LayoutName) -> [Character: Set<Character>] {
    var positions: [(Character, Double, Int)] = []
    for (r, row) in letterRows[layout]!.enumerated() {
        let offset = Double(10 - row.count) / 2 // short rows are centered
        for (c, ch) in row.enumerated() where ch.isLetter { positions.append((ch, Double(c) + offset, r)) }
    }
    var out: [Character: Set<Character>] = [:]
    for (a, ax, ar) in positions {
        out[a] = Set(positions.filter { $0.0 != a && abs($0.2 - ar) <= 1 && abs($0.1 - ax) <= 1.1 }.map { $0.0 })
    }
    return out
}
