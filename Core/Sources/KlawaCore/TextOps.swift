import Foundation

public enum TextOps {
    /// Second space within 0.6 s after a word becomes ". " (iOS shortcut).
    public static func shouldInsertPeriod(contextBefore: String?, lastSpaceAt: TimeInterval?, now: TimeInterval) -> Bool {
        guard let before = contextBefore, let t = lastSpaceAt, now - t <= 0.6, before.hasSuffix(" "),
              let c = before.dropLast().last else { return false }
        return c.isLetter || c.isNumber
    }

    /// Characters to delete for one word-delete: trailing whitespace, then a run of word
    /// characters or a run of other non-space characters (punctuation, emoji).
    public static func wordDeleteCount(contextBefore: String?) -> Int {
        var chars = Array(contextBefore ?? "")
        var count = 0
        while let c = chars.last, c.isWhitespace { chars.removeLast(); count += 1 }
        guard let last = chars.last else { return count }
        let isWord = { (c: Character) in c.isLetter || c.isNumber }
        let sameRun = isWord(last) ? isWord : { (c: Character) in !isWord(c) && !c.isWhitespace }
        while let c = chars.last, sameRun(c) { chars.removeLast(); count += 1 }
        return count
    }

    /// UTF-16 offset for `adjustTextPosition` that moves `step` whole Characters (negative = left),
    /// so the cursor never lands inside an emoji or combined letter. Unknown context: pass the step through.
    public static func cursorOffset(step: Int, contextBefore: String?, contextAfter: String?) -> Int {
        let side = Array((step < 0 ? contextBefore : contextAfter) ?? "")
        guard !side.isEmpty else { return step }
        let n = min(abs(step), side.count)
        let moved = step < 0 ? Array(side.suffix(n)) : Array(side.prefix(n))
        let units = moved.reduce(0) { $0 + $1.utf16.count }
        return step < 0 ? -units : units
    }
}

extension TextOps {
    private static func isWordChar(_ c: Character) -> Bool { c.isLetter || c == "'" || c == "’" }

    /// Word right before the cursor (letters and apostrophes), "" after a space or punctuation.
    public static func currentWord(contextBefore: String?) -> String {
        var word = String((contextBefore ?? "").reversed().prefix(while: isWordChar).reversed())
        while let f = word.first, !f.isLetter { word.removeFirst() }
        return word
    }

    /// Word before the current one, if only spaces separate them (no sentence break).
    public static func previousWord(contextBefore: String?) -> String? {
        var rest = Substring(contextBefore ?? "")
        rest = rest.dropLast(currentWord(contextBefore: contextBefore).count)
        guard rest.last == " " else { return nil }
        while rest.last == " " { rest.removeLast() }
        let word = currentWord(contextBefore: String(rest))
        return word.isEmpty ? nil : word
    }
}

/// Picks the key a touch meant: closeness to each key center plus how likely its letter
/// comes next. The bias is capped, so a touch near a key's center always gets that key.
public enum TouchModel {
    static let sigma = 0.45      // in key pitches
    static let weight = 0.4      // how much the letter odds count
    static let maxLogRatio = 3.0 // odds above e^3 = 20x count no more

    /// `offsets`: touch minus key center, in key pitches. `masses`: likelihood of each key's letter.
    public static func pick(offsets: [(dx: Double, dy: Double)], masses: [Double]) -> Int {
        let top = masses.max() ?? 0
        guard top > 0 else { return nearest(offsets) }
        let scores = zip(offsets, masses).map { o, m in
            -(o.dx * o.dx + o.dy * o.dy) / (2 * sigma * sigma) + weight * max(log(m / top), -maxLogRatio)
        }
        return scores.indices.max { scores[$0] < scores[$1] } ?? 0
    }

    static func nearest(_ offsets: [(dx: Double, dy: Double)]) -> Int {
        offsets.indices.min { hypot(offsets[$0].dx, offsets[$0].dy) < hypot(offsets[$1].dx, offsets[$1].dy) } ?? 0
    }
}

public enum PopupGeometry {
    /// Left edge of a popup centered on a key, kept inside the container.
    public static func originX(keyMidX: Double, popupWidth: Double, containerWidth: Double, margin: Double = 2) -> Double {
        clamp(keyMidX - popupWidth / 2, popupWidth: popupWidth, containerWidth: containerWidth, margin: margin)
    }

    /// Long-press strip: the first option sits right above the finger and the rest extend
    /// away from the nearer screen edge (to the left for keys on the right half).
    public static func alternatesOriginX(keyMidX: Double, popupWidth: Double, cellWidth: Double, pad: Double,
                                         containerWidth: Double, rightToLeft: Bool, margin: Double = 2) -> Double {
        let firstCellLeft = keyMidX - cellWidth / 2
        let x = rightToLeft ? firstCellLeft + cellWidth + pad - popupWidth : firstCellLeft - pad
        return clamp(x, popupWidth: popupWidth, containerWidth: containerWidth, margin: margin)
    }

    /// Selected option from how far the finger moved since the popup opened (dy < 0 = up).
    /// No movement keeps the first option, so a plain release picks it.
    public static func alternateIndex(dx: Double, dy: Double, cellWidth: Double, cellHeight: Double,
                                      columns: Int, count: Int, rightToLeft: Bool) -> Int {
        let rows = (count + columns - 1) / columns
        let col = min(max(Int(((rightToLeft ? -dx : dx) / cellWidth).rounded()), 0), columns - 1)
        let row = min(max(Int((-dy / cellHeight).rounded()), 0), rows - 1)
        return min(row * columns + col, count - 1)
    }

    private static func clamp(_ x: Double, popupWidth: Double, containerWidth: Double, margin: Double) -> Double {
        min(max(x, margin), containerWidth - popupWidth - margin)
    }
}
