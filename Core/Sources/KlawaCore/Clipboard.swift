import Foundation

public struct Clip: Codable, Equatable {
    public var text: String
    public var date: Date
    public var pinned: Bool

    public init(text: String, date: Date, pinned: Bool = false) {
        self.text = text
        self.date = date
        self.pinned = pinned
    }
}

/// Copied texts: pinned ones stay, the rest disappear after an hour. Kept only in the keyboard's container.
public struct ClipboardHistory: Codable, Equatable {
    /// Pinned first, then newest first.
    public private(set) var clips: [Clip] = []
    public static let lifetime: TimeInterval = 3600
    static let limit = 30

    public init() {}

    public mutating func add(_ text: String, at date: Date) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let pinned = clips.first { $0.text == text }?.pinned ?? false
        clips.removeAll { $0.text == text }
        clips.append(Clip(text: text, date: date, pinned: pinned))
        sort()
        while clips.filter({ !$0.pinned }).count > Self.limit, let last = clips.lastIndex(where: { !$0.pinned }) {
            clips.remove(at: last)
        }
    }

    public mutating func expire(now: Date) {
        clips.removeAll { !$0.pinned && now.timeIntervalSince($0.date) > Self.lifetime }
    }

    public mutating func togglePin(_ i: Int) {
        guard clips.indices.contains(i) else { return }
        clips[i].pinned.toggle()
        sort()
    }

    public mutating func remove(_ i: Int) {
        guard clips.indices.contains(i) else { return }
        clips.remove(at: i)
    }

    public mutating func clearUnpinned() { clips.removeAll { !$0.pinned } }

    private mutating func sort() {
        clips.sort { ($0.pinned ? 1 : 0, $0.date) > ($1.pinned ? 1 : 0, $1.date) }
    }
}

public enum ClipExtract {
    /// Links, emails and phone numbers inside a copied text, each pasteable on its own.
    public static func items(in text: String) -> [String] {
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return [] }
        var out: [String] = []
        for m in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            var item: String?
            if m.resultType == .phoneNumber {
                item = m.phoneNumber
            } else if let url = m.url {
                item = url.scheme == "mailto" ? String(url.absoluteString.dropFirst("mailto:".count))
                    : Range(m.range, in: text).map { String(text[$0]) }
            }
            if let item, item != text.trimmingCharacters(in: .whitespacesAndNewlines), !out.contains(item) { out.append(item) }
        }
        return out
    }
}
