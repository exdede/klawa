import UIKit
import KlawaCore

/// Emoji grid that replaces the keys: recents first, category bar at the bottom.
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onBackspace: (() -> Void)?

    static let catalog: [EmojiGroup] = {
        guard let url = Bundle.main.url(forResource: "emoji", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return EmojiCatalog.parse(text)
    }()

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

        collection.backgroundColor = .clear
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: "e")
        collection.register(EmojiHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "h")
        collection.dataSource = self
        collection.delegate = self

        let bar = UIStackView()
        bar.distribution = .fillEqually
        bar.addArrangedSubview(button(title: "ABC") { [weak self] in self?.onClose?() })
        for (i, group) in groups.enumerated() {
            bar.addArrangedSubview(button(title: Self.symbols[group.name] ?? "•") { [weak self] in self?.jump(to: i) })
        }
        bar.addArrangedSubview(button(symbol: "delete.left") { [weak self] in self?.onBackspace?() })

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

    private func button(title: String? = nil, symbol: String? = nil, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: title == "ABC" ? 15 : 20)
        if let symbol { b.setImage(UIImage(systemName: symbol), for: .normal) }
        b.tintColor = .label
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    private func jump(to section: Int) {
        guard let attrs = collection.layoutAttributesForSupplementaryElement(
            ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)) else { return }
        collection.setContentOffset(CGPoint(x: 0, y: min(attrs.frame.minY, max(0, collection.contentSize.height - collection.bounds.height))), animated: false)
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
