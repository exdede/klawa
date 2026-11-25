import UIKit
import KlawaCore

enum BackspaceUnit { case character, word }

/// Draws the keys and handles every touch itself: multitouch, sliding between keys,
/// long-press alternates, backspace repeat and space-bar cursor drag.
final class KeyboardView: UIView {
    var onInsert: ((String) -> Void)?
    var onKey: ((KeyKind) -> Void)?
    var onBackspace: ((BackspaceUnit) -> Void)?
    var onCursorMove: ((Int) -> Void)?
    var onGlobe: ((UIView, UIEvent) -> Void)?
    var onPress: (() -> Void)?
    /// How likely each lowercase letter is to come next (nil = no idea): makes likely keys
    /// invisibly bigger, like the iOS keyboard.
    var letterOdds: (([String]) -> [Double]?)?
    /// Letter bubble above the pressed key (setting); without it the key just darkens.
    var showsBubble = false
    /// Popups are added here; it must contain this view and the space above it.
    weak var popupHost: UIView?

    private var rows: [[Key]] = []
    private var keys: [Key] = []
    private var keyViews: [KeyView] = []
    private var rowRanges: [Range<Int>] = []
    private var uppercase = false

    private enum Mode { case normal, alternates(AlternatesPopup), cursor, backspace, function }

    private final class Track {
        var keyIndex: Int
        let downAt = CACurrentMediaTime()
        var mode: Mode = .normal
        var committed = false
        var timer: Timer?
        var bubble: UIView?
        var anchor: CGPoint
        var lastPoint: CGPoint
        var lastX: CGFloat
        var cursorMoved = false
        init(keyIndex: Int, point: CGPoint) { self.keyIndex = keyIndex; anchor = point; lastPoint = point; lastX = point.x }
    }

    private var tracks: [ObjectIdentifier: Track] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = KeyStyle.touchable // touches in the gaps between keys count too
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rows: [[Key]], uppercase: Bool, shift: ShiftState, languageLabel: String, spaceLabel: String, returnLabel: String?) {
        if rows != self.rows {
            self.rows = rows
            rebuild()
        }
        self.uppercase = uppercase
        for (key, view) in zip(keys, keyViews) {
            view.show(key, uppercase: uppercase, shift: shift, languageLabel: languageLabel, spaceLabel: spaceLabel, returnLabel: returnLabel)
        }
    }

    private func rebuild() {
        for t in tracks.values { end(t) }
        tracks.removeAll()
        keyViews.forEach { $0.removeFromSuperview() }
        keys = rows.flatMap { $0 }
        keyViews = keys.map { _ in KeyView() }
        keyViews.forEach { addSubview($0) }
        var start = 0
        rowRanges = rows.map { row in
            defer { start += row.count }
            return start..<(start + row.count)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gap = KeyStyle.keyGap
        let available = bounds.width - 2 * KeyStyle.sideMargin
        let unit = (available - 9 * gap) / 10
        for (r, range) in rowRanges.enumerated() {
            let units = CGFloat(range.reduce(0.0) { $0 + keys[$1].width })
            var x = KeyStyle.sideMargin + (available - (units * unit + (units - 1) * gap)) / 2
            let y = KeyStyle.topPadding + CGFloat(r) * (KeyStyle.keyHeight + KeyStyle.rowGap)
            for i in range {
                let width = CGFloat(keys[i].width)
                let w = width * unit + (width - 1) * gap
                keyViews[i].frame = CGRect(x: x, y: y, width: w, height: KeyStyle.keyHeight)
                x += w + gap
            }
        }
    }

    /// Nearest key, so touches in the gaps still hit something.
    private func keyIndex(at p: CGPoint) -> Int? {
        guard !rowRanges.isEmpty else { return nil }
        let r = Int((p.y - KeyStyle.topPadding + KeyStyle.rowGap / 2) / (KeyStyle.keyHeight + KeyStyle.rowGap))
        let range = rowRanges[min(max(r, 0), rowRanges.count - 1)]
        return range.min { distance(p.x, keyViews[$0].frame) < distance(p.x, keyViews[$1].frame) }
    }

    /// Touches a little above the top row (on the suggestion bar's edge) still type.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -6, left: 0, bottom: 0, right: 0)).contains(point)
    }

    private func letter(_ i: Int) -> String? {
        guard case .character(let s) = keys[i].kind, s.count == 1, s.first!.isLetter else { return nil }
        return s
    }

    /// Among letter keys around the touch, the one the owner most likely meant.
    private func likelyKey(at p: CGPoint, nearest i: Int) -> Int {
        guard letter(i) != nil, let letterOdds else { return i }
        let pitchX = keyViews[i].frame.width + KeyStyle.keyGap
        let pitchY = KeyStyle.keyHeight + KeyStyle.rowGap
        let near = keys.indices.filter { j in
            letter(j) != nil && abs(keyViews[j].frame.midX - p.x) < 1.5 * pitchX && abs(keyViews[j].frame.midY - p.y) < 1.5 * pitchY
        }
        guard near.count > 1, let masses = letterOdds(near.map { letter($0)! }) else { return i }
        let offsets = near.map { j in
            (dx: Double((p.x - keyViews[j].frame.midX) / pitchX), dy: Double((p.y - keyViews[j].frame.midY) / pitchY))
        }
        return near[TouchModel.pick(offsets: offsets, masses: masses)]
    }

    private func distance(_ x: CGFloat, _ f: CGRect) -> CGFloat {
        x < f.minX ? f.minX - x : (x > f.maxX ? x - f.maxX : 0)
    }

    private func text(_ s: String) -> String { uppercase ? s.uppercased() : s }

    // MARK: touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let p = touch.location(in: self)
            guard let nearest = keyIndex(at: p) else { continue }
            commitPendingCharacters() // fast typing: the earlier finger's letter goes first
            let t = Track(keyIndex: likelyKey(at: p, nearest: nearest), point: p)
            tracks[ObjectIdentifier(touch)] = t
            onPress?()
            begin(t, event: event)
        }
    }

    private func begin(_ t: Track, event: UIEvent?) {
        let kind = keys[t.keyIndex].kind
        switch kind {
        case .character:
            showPress(t)
            startLongPress(t)
        case .backspace:
            t.mode = .backspace
            keyViews[t.keyIndex].setPressed(true)
            onBackspace?(.character)
            var tick = 0
            t.timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self, weak t] _ in
                guard let self, let t else { return }
                let held = CACurrentMediaTime() - t.downAt
                guard held >= 0.45 else { return }
                tick += 1
                if held < 1.6 {
                    self.onBackspace?(.character)
                } else if tick % 3 == 0 {
                    self.onBackspace?(.word)
                }
            }
        case .space:
            keyViews[t.keyIndex].setPressed(true)
            t.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self, weak t] _ in
                guard let self, let t, case .normal = t.mode else { return }
                self.setCursorMode(t, on: true)
            }
        case .shift:
            t.mode = .function
            keyViews[t.keyIndex].setPressed(true)
            onKey?(.shift) // on touch-down, so a quick double tap is caps lock
        case .globe:
            t.mode = .function
            if let event { onGlobe?(keyViews[t.keyIndex], event) }
        default:
            t.mode = .function
            keyViews[t.keyIndex].setPressed(true)
        }
    }

    private func startLongPress(_ t: Track) {
        t.timer?.invalidate()
        guard !keys[t.keyIndex].alternates.isEmpty else { return }
        t.timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self, weak t] _ in
            guard let self, let t, !t.committed, case .normal = t.mode else { return }
            self.openAlternates(t)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracks[ObjectIdentifier(touch)] else { continue }
            let p = touch.location(in: self)
            t.lastPoint = p
            switch t.mode {
            case .normal:
                if keys[t.keyIndex].kind == .space {
                    // a thumb rolls on the wide space bar; only a clear sideways drag moves the cursor
                    if abs(p.x - t.anchor.x) > 25 { setCursorMode(t, on: true) }
                } else if !t.committed, hypot(p.x - t.anchor.x, p.y - t.anchor.y) > 14,
                          let j = keyIndex(at: p), j != t.keyIndex, case .character = keys[j].kind {
                    keyViews[t.keyIndex].setPressed(false)
                    t.keyIndex = j
                    showPress(t)
                    startLongPress(t)
                }
            case .alternates(let popup):
                popup.select(dx: p.x - t.anchor.x, dy: p.y - t.anchor.y)
            case .cursor:
                let steps = Int((p.x - t.lastX) / 9)
                if steps != 0 {
                    onCursorMove?(steps)
                    t.lastX += CGFloat(steps) * 9
                    t.cursorMoved = true
                }
            case .function:
                if keys[t.keyIndex].kind == .globe, let event { onGlobe?(keyViews[t.keyIndex], event) }
            case .backspace:
                break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracks.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            end(t)
            switch t.mode {
            case .normal:
                switch keys[t.keyIndex].kind {
                case .character(let s): if !t.committed { onInsert?(text(s)) }
                case .space: onKey?(.space)
                default: break
                }
            case .alternates(let popup):
                if let s = popup.selected { onInsert?(s) }
            case .function:
                let kind = keys[t.keyIndex].kind
                if kind == .globe {
                    if let event { onGlobe?(keyViews[t.keyIndex], event) }
                } else if kind != .shift, keyIndex(at: touch.location(in: self)) == t.keyIndex {
                    onKey?(kind) // may rebuild the keys, so it goes last
                }
            case .cursor:
                if !t.cursorMoved { onKey?(.space) }
            case .backspace:
                break
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let t = tracks.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            end(t)
            // iOS sometimes cancels keyboard touches; a lost tap is worse than a kept one
            guard case .normal = t.mode else { continue }
            switch keys[t.keyIndex].kind {
            case .character(let s): if !t.committed { onInsert?(text(s)) }
            case .space: onKey?(.space)
            default: break
            }
        }
    }

    /// Stops timers and removes everything a track put on screen. Inserts nothing.
    private func end(_ t: Track) {
        t.timer?.invalidate()
        t.bubble?.removeFromSuperview()
        t.bubble = nil
        if t.keyIndex < keyViews.count { keyViews[t.keyIndex].setPressed(false) }
        switch t.mode {
        case .alternates(let popup): popup.removeFromSuperview()
        case .cursor: setCursorMode(t, on: false)
        default: break
        }
    }

    private func commitPendingCharacters() {
        let pending = tracks.values.filter { t in
            guard !t.committed, case .normal = t.mode, case .character = keys[t.keyIndex].kind else { return false }
            return true
        }
        for t in pending.sorted(by: { $0.downAt < $1.downAt }) {
            guard case .character(let s) = keys[t.keyIndex].kind else { continue }
            t.committed = true
            t.timer?.invalidate()
            t.bubble?.removeFromSuperview()
            t.bubble = nil
            onInsert?(text(s))
        }
    }

    // MARK: popups

    private func hostFrame(of i: Int) -> (CGRect, UIView)? {
        guard let host = popupHost else { return nil }
        return (convert(keyViews[i].frame, to: host), host)
    }

    private func showPress(_ t: Track) {
        if showsBubble { showBubble(t) } else { keyViews[t.keyIndex].setPressed(true) }
    }

    private func showBubble(_ t: Track) {
        t.bubble?.removeFromSuperview()
        guard case .character(let s) = keys[t.keyIndex].kind, let frame = hostFrame(of: t.keyIndex) else { return }
        let (key, host) = frame
        let w = max(key.width + 14, 44)
        let h: CGFloat = 52
        let x = PopupGeometry.originX(keyMidX: key.midX, popupWidth: w, containerWidth: host.bounds.width)
        let bubble = PopupBox(frame: CGRect(x: x, y: max(0, key.minY - h + 4), width: w, height: h))
        let label = UILabel(frame: bubble.bounds)
        label.text = text(s)
        label.font = .systemFont(ofSize: 32, weight: .light)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        bubble.addSubview(label)
        host.addSubview(bubble)
        t.bubble = bubble
    }

    private func openAlternates(_ t: Track) {
        guard let frame = hostFrame(of: t.keyIndex) else { return }
        let (key, host) = frame
        t.bubble?.removeFromSuperview()
        t.bubble = nil
        let options = keys[t.keyIndex].alternates.map { text($0) }
        let rightToLeft = key.midX > host.bounds.width / 2
        let popup = AlternatesPopup(options: options, rightToLeft: rightToLeft)
        let size = popup.bounds.size
        popup.frame.origin = CGPoint(
            x: PopupGeometry.alternatesOriginX(keyMidX: key.midX, popupWidth: size.width, cellWidth: AlternatesPopup.cell.width,
                                               pad: AlternatesPopup.pad, containerWidth: host.bounds.width, rightToLeft: rightToLeft),
            y: max(0, key.minY - size.height - 2)
        )
        host.addSubview(popup)
        t.anchor = t.lastPoint
        t.mode = .alternates(popup)
    }

    private func setCursorMode(_ t: Track, on: Bool) {
        if on {
            t.timer?.invalidate()
            t.mode = .cursor
            t.lastX = t.lastPoint.x
        }
        keyViews.forEach { $0.setDimmed(on) }
    }
}

/// Rounded key-colored box used for the press bubble and the alternates strip.
class PopupBox: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyStyle.letterKey
        layer.cornerRadius = KeyStyle.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Grid of long-press options. The first option sits above the finger; rows grow upward,
/// columns grow away from the nearer screen edge.
final class AlternatesPopup: PopupBox {
    private let options: [String]
    private let rightToLeft: Bool
    private let cols: Int
    private let rowCount: Int
    private var labels: [UILabel] = []
    static let cell = CGSize(width: 34, height: 42)
    static let pad: CGFloat = 4
    private(set) var selectedIndex = 0
    var selected: String? { options.indices.contains(selectedIndex) ? options[selectedIndex] : nil }

    init(options: [String], rightToLeft: Bool) {
        self.options = options
        self.rightToLeft = rightToLeft
        cols = min(max(options.count, 1), 8)
        rowCount = (options.count + cols - 1) / cols
        let cell = Self.cell
        super.init(frame: CGRect(x: 0, y: 0, width: CGFloat(cols) * cell.width + 2 * Self.pad,
                                 height: CGFloat(rowCount) * cell.height + 2 * Self.pad))
        for (i, option) in options.enumerated() {
            let col = rightToLeft ? cols - 1 - i % cols : i % cols
            let label = UILabel(frame: CGRect(
                x: Self.pad + CGFloat(col) * cell.width,
                y: Self.pad + CGFloat(rowCount - 1 - i / cols) * cell.height,
                width: cell.width, height: cell.height))
            label.text = option
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.layer.cornerRadius = 6
            label.layer.cornerCurve = .continuous
            label.clipsToBounds = true
            addSubview(label)
            labels.append(label)
        }
        highlight()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// `dx`/`dy`: finger movement since the popup opened.
    func select(dx: CGFloat, dy: CGFloat) {
        let index = PopupGeometry.alternateIndex(dx: dx, dy: dy, cellWidth: Self.cell.width, cellHeight: Self.cell.height,
                                                 columns: cols, count: options.count, rightToLeft: rightToLeft)
        guard index != selectedIndex else { return }
        selectedIndex = index
        highlight()
    }

    private func highlight() {
        for (i, label) in labels.enumerated() {
            label.backgroundColor = i == selectedIndex ? .systemBlue : .clear
            label.textColor = i == selectedIndex ? .white : .label
        }
    }
}

final class KeyView: UIView {
    private let label = UILabel()
    private let icon = UIImageView()
    private let hint = UILabel()
    private var isFunction = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = KeyStyle.cornerRadius
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = false
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        icon.contentMode = .center
        icon.tintColor = .label
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabel
        hint.textAlignment = .right
        [label, icon, hint].forEach { addSubview($0) }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: KeyView, _: UITraitCollection) in
            view.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        icon.frame = bounds
        hint.frame = CGRect(x: bounds.width - 14, y: 2, width: 11, height: 12)
        KeyStyle.applyShadow(layer, bounds: bounds, traits: traitCollection)
    }

    func show(_ key: Key, uppercase: Bool, shift: ShiftState, languageLabel: String, spaceLabel: String, returnLabel: String?) {
        var title: String?
        var symbol: String?
        var font = UIFont.systemFont(ofSize: 16)
        var color = UIColor.label
        isFunction = true
        switch key.kind {
        case .character(let s):
            isFunction = false
            title = uppercase ? s.uppercased() : s
            let isLetter = s.count == 1 && s.first!.isLetter
            font = .systemFont(ofSize: isLetter ? 23 : (s.count > 1 ? 18 : 21))
        case .space:
            isFunction = false
            title = spaceLabel
            font = .systemFont(ofSize: 15)
            color = .secondaryLabel
        case .language:
            title = languageLabel
            font = .systemFont(ofSize: 16, weight: .medium)
        case .pageNumbers: title = "123"
        case .pageSymbols: title = "#+="
        case .pageLetters: title = "ABC"
        case .shift: symbol = shift == .capsLock ? "capslock.fill" : (shift == .on ? "shift.fill" : "shift")
        case .backspace: symbol = "delete.left"
        case .emoji: symbol = "face.smiling"
        case .globe: symbol = "globe"
        case .returnKey:
            if let returnLabel { title = returnLabel } else { symbol = "return.left" }
        }
        label.text = title
        label.font = font
        label.textColor = color
        icon.image = symbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19)) }
        hint.text = key.hint
        backgroundColor = isFunction ? KeyStyle.functionKey : KeyStyle.letterKey
    }

    func setPressed(_ on: Bool) {
        let pressedColor = isFunction ? KeyStyle.letterKey : KeyStyle.functionKey
        backgroundColor = on ? pressedColor : (isFunction ? KeyStyle.functionKey : KeyStyle.letterKey)
    }

    func setDimmed(_ on: Bool) {
        let alpha: CGFloat = on ? 0.25 : 1
        label.alpha = alpha
        icon.alpha = alpha
        hint.alpha = alpha
    }
}
