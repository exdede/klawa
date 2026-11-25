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

public enum PopupGeometry {
    /// Left edge of a popup centered on a key, kept inside the container.
    public static func originX(keyMidX: Double, popupWidth: Double, containerWidth: Double, margin: Double = 2) -> Double {
        min(max(keyMidX - popupWidth / 2, margin), containerWidth - popupWidth - margin)
    }
}
