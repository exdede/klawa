import UIKit

/// Strip above the keys: three suggestion slots like iOS (best in the middle), or the
/// emoji search query with matching emoji.
final class SuggestionBar: UIView {
    var onSlot: ((Int) -> Void)?
    var onEmoji: ((String) -> Void)?
    var onCloseSearch: (() -> Void)?
    var onClipboard: (() -> Void)?
    var onSnippets: (() -> Void)?
    var onTranslate: (() -> Void)?
    var onTranslationTap: (() -> Void)?

    private let slots = UIStackView()
    private let slotRow = UIStackView()
    private var slotLabels: [UILabel] = []
    private var texts: [String?] = []
    private var highlighted: Int?
    /// Slot under the finger; the bar handles slot touches itself, so a tap anywhere in a slot's
    /// third of the bar counts, even if the finger slides a bit.
    private var pressedSlot: Int?
    private let search = UIStackView()
    private let queryLabel = UILabel()
    private let results = UIScrollView()
    private let resultsStack = UIStackView()
    private let translateRow = UIStackView()
    private let translateSource = UILabel()
    private let translateResult = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyStyle.touchable
        slots.distribution = .fillEqually
        slots.spacing = 4
        slotRow.addArrangedSubview(icon("clipboard") { [weak self] in self?.onClipboard?() })
        slotRow.addArrangedSubview(icon("text.bubble") { [weak self] in self?.onSnippets?() })
        slotRow.addArrangedSubview(icon("translate") { [weak self] in self?.onTranslate?() })
        slotRow.addArrangedSubview(slots)
        for _ in 0..<3 {
            let l = UILabel()
            l.font = .systemFont(ofSize: 17)
            l.lineBreakMode = .byTruncatingMiddle
            l.textAlignment = .center
            l.layer.cornerRadius = 8
            l.layer.cornerCurve = .continuous
            l.clipsToBounds = true
            slotLabels.append(l)
            slots.addArrangedSubview(l)
        }

        queryLabel.font = .systemFont(ofSize: 16)
        queryLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        resultsStack.spacing = 2
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        results.showsHorizontalScrollIndicator = false
        results.delaysContentTouches = false
        results.addSubview(resultsStack)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .secondaryLabel
        close.widthAnchor.constraint(equalToConstant: 40).isActive = true
        close.addAction(UIAction { [weak self] _ in self?.onCloseSearch?() }, for: .touchUpInside)
        search.spacing = 6
        [queryLabel, results, close].forEach { search.addArrangedSubview($0) }
        search.isHidden = true

        translateSource.font = .systemFont(ofSize: 12)
        translateSource.textColor = .secondaryLabel
        translateSource.lineBreakMode = .byTruncatingHead
        translateResult.font = .systemFont(ofSize: 16)
        translateResult.lineBreakMode = .byTruncatingHead
        let texts = UIStackView(arrangedSubviews: [translateSource, translateResult])
        texts.axis = .vertical
        let closeTranslate = UIButton(type: .system)
        closeTranslate.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeTranslate.tintColor = .secondaryLabel
        closeTranslate.widthAnchor.constraint(equalToConstant: 40).isActive = true
        closeTranslate.addAction(UIAction { [weak self] _ in self?.onCloseSearch?() }, for: .touchUpInside)
        translateRow.spacing = 6
        [texts, closeTranslate].forEach { translateRow.addArrangedSubview($0) }
        translateRow.isHidden = true

        for v in [slotRow, search, translateRow] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                v.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
                v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            ])
        }
        NSLayoutConstraint.activate([
            resultsStack.topAnchor.constraint(equalTo: results.contentLayoutGuide.topAnchor),
            resultsStack.bottomAnchor.constraint(equalTo: results.contentLayoutGuide.bottomAnchor),
            resultsStack.leadingAnchor.constraint(equalTo: results.contentLayoutGuide.leadingAnchor),
            resultsStack.trailingAnchor.constraint(equalTo: results.contentLayoutGuide.trailingAnchor),
            resultsStack.heightAnchor.constraint(equalTo: results.frameLayoutGuide.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func icon(_ symbol: String, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.tintColor = .secondaryLabel
        b.backgroundColor = KeyStyle.touchable
        b.widthAnchor.constraint(equalToConstant: 36).isActive = true
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    private func slot(at p: CGPoint) -> Int? {
        guard !slotRow.isHidden, bounds.insetBy(dx: 0, dy: -20).contains(p) else { return nil }
        let x = convert(p, to: slots).x
        guard x >= 0, x <= slots.bounds.width, slots.bounds.width > 0 else { return nil }
        return min(2, Int(x / (slots.bounds.width / 3)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        pressedSlot = slot(at: t.location(in: self)).flatMap { texts.indices.contains($0) && texts[$0] != nil ? $0 : nil }
        paint()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !translateRow.isHidden { return onTranslationTap?() ?? () }
        let picked = pressedSlot
        pressedSlot = nil
        paint()
        if let picked, let t = touches.first, bounds.insetBy(dx: -10, dy: -30).contains(t.location(in: self)) {
            onSlot?(picked)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressedSlot = nil
        paint()
    }

    private func paint() {
        for (i, l) in slotLabels.enumerated() {
            l.backgroundColor = i == pressedSlot ? KeyStyle.functionKey : (i == highlighted ? KeyStyle.letterKey : KeyStyle.touchable)
        }
    }

    /// `highlighted`: the slot space will pick (autocorrect), drawn like a key.
    func show(_ texts: [String?], highlighted: Int?) {
        slotRow.isHidden = false
        search.isHidden = true
        translateRow.isHidden = true
        self.texts = (0..<3).map { $0 < texts.count ? texts[$0] : nil }
        self.highlighted = highlighted
        for (l, text) in zip(slotLabels, self.texts) { l.text = text }
        paint()
    }

    /// Translator: what is typed (small) and its translation; tapping the bar inserts the translation.
    func showTranslate(direction: String, query: String, result: String) {
        slotRow.isHidden = true
        search.isHidden = true
        translateRow.isHidden = false
        translateSource.text = direction + "  " + query + "▏"
        translateResult.text = result.isEmpty ? "Pisz, tłumaczenie pojawi się tutaj" : result
        translateResult.textColor = result.isEmpty ? .tertiaryLabel : .label
    }

    func showSearch(query: String, emoji: [String]) {
        slotRow.isHidden = true
        translateRow.isHidden = true
        search.isHidden = false
        queryLabel.text = "🔍 " + query + "▏"
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for e in emoji {
            let b = UIButton(type: .custom)
            b.setTitle(e, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 28)
            b.widthAnchor.constraint(equalToConstant: 40).isActive = true
            b.addAction(UIAction { [weak self] _ in self?.onEmoji?(e) }, for: .touchUpInside)
            resultsStack.addArrangedSubview(b)
        }
        results.contentOffset = .zero
    }
}
