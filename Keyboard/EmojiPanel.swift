import UIKit
import KlawaCore

/// Emoji grid that replaces the keys: recents first, category bar at the bottom.
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
    var onEmoji: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onBackspace: (() -> Void)?
    var onSearch: (() -> Void)?

    static let catalog: [EmojiGroup] = {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return EmojiCatalog.parse(text)
    }()

    /// emoji -> its 5 skin-tone variants (scripts/gen-emoji.py)
    static let tones: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "emoji-tones", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var out: [String: [String]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            if parts.count == 2 { out[String(parts[0])] = parts[1].split(separator: " ").map(String.init) }
        }
        return out
    }()

    private var tonePopup: AlternatesPopup?
    private var toneAnchor = CGPoint.zero

    private static let symbols = [
        "Recent": "🕘", "Smileys": "😀", "People": "👋", "Animals": "🐻", "Food": "🍔",
        "Travel": "🚗", "Activities": "⚽", "Objects": "💡", "Symbols": "❤️", "Flags": "🏳️",
    ]

    private let groups: [EmojiGroup]
    private let collection: UICollectionView

    init(recents: [String]) {
        groups = (recents.isEmpty ? [] : [EmojiGroup(name: "Recent", emojis: recents)]) + Self.catalog
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.headerReferenceSize = CGSize(width: 0, height: 24)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        backgroundColor = KeyStyle.touchable

        collection.backgroundColor = KeyStyle.touchable
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: "e")
        collection.register(EmojiHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "h")
        collection.dataSource = self
        collection.delegate = self
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdEmoji(_:)))
        hold.minimumPressDuration = 0.35
        hold.delegate = self
        collection.addGestureRecognizer(hold)

        let bar = UIStackView()
        bar.distribution = .fillEqually
        bar.addArrangedSubview(PanelButton.make(title: "ABC") { [weak self] in self?.onClose?() })
        bar.addArrangedSubview(PanelButton.make(symbol: "magnifyingglass") { [weak self] in self?.onSearch?() })
        for (i, group) in groups.enumerated() {
            bar.addArrangedSubview(PanelButton.make(title: Self.symbols[group.name] ?? "•", fontSize: 20) { [weak self] in self?.jump(to: i) })
        }
        bar.addArrangedSubview(PanelButton.make(symbol: "delete.left", repeats: true) { [weak self] in self?.onBackspace?() })

        for v in [collection, bar] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: topAnchor),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.topAnchor.constraint(equalTo: collection.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyStyle.bottomPadding),
            bar.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func jump(to section: Int) {
        guard let attrs = collection.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)) else { return }
        collection.setContentOffset(CGPoint(x: 0, y: min(attrs.frame.minY, max(0, collection.contentSize.height - collection.bounds.height))), animated: false)
    }

    /// Only emoji with skin tones react to holding; a slow tap on any other still inserts it.
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g is UILongPressGestureRecognizer else { return super.gestureRecognizerShouldBegin(g) }
        guard let path = collection.indexPathForItem(at: g.location(in: collection)) else { return false }
        return Self.tones[groups[path.section].emojis[path.item]] != nil
    }

    /// Hold an emoji with skin tones: slide to a tone, release to insert it (like long-press on keys).
    @objc private func holdEmoji(_ g: UILongPressGestureRecognizer) {
        let host = superview ?? self
        switch g.state {
        case .began:
            guard let path = collection.indexPathForItem(at: g.location(in: collection)),
                  let cell = collection.cellForItem(at: path) else { return }
            let emoji = groups[path.section].emojis[path.item]
            guard let variants = Self.tones[emoji] else { return }
            let frame = cell.convert(cell.bounds, to: host)
            let rightToLeft = frame.midX > host.bounds.width / 2
            let popup = AlternatesPopup(options: [emoji] + variants, rightToLeft: rightToLeft, fontSize: 30)
            let size = popup.bounds.size
            popup.frame.origin = CGPoint(
                x: PopupGeometry.alternatesOriginX(keyMidX: frame.midX, popupWidth: size.width, cellWidth: AlternatesPopup.cell.width,
                                                   pad: AlternatesPopup.pad, containerWidth: host.bounds.width, rightToLeft: rightToLeft),
                y: max(0, frame.minY - size.height - 2))
            host.addSubview(popup)
            tonePopup = popup
            toneAnchor = g.location(in: host)
        case .changed:
            let p = g.location(in: host)
            tonePopup?.select(dx: p.x - toneAnchor.x, dy: p.y - toneAnchor.y)
        case .ended:
            if let s = tonePopup?.selected { onEmoji?(s) }
            fallthrough
        default:
            tonePopup?.removeFromSuperview()
            tonePopup = nil
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { groups.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        groups[section].emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "e", for: indexPath) as! EmojiCell
        cell.label.text = groups[indexPath.section].emojis[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "h", for: indexPath) as! EmojiHeader
        header.label.text = groups[indexPath.section].name.uppercased()
        return header
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: floor(collectionView.bounds.width / 8), height: 44)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onEmoji?(groups[indexPath.section].emojis[indexPath.item])
    }
}

private final class EmojiCell: UICollectionViewCell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 32)
        label.textAlignment = .center
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}

private final class EmojiHeader: UICollectionReusableView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 8, dy: 0)
    }
}
