import UIKit

/// Strip above the keys: three suggestion slots like iOS (best in the middle), or the
/// emoji search query with matching emoji.
final class SuggestionBar: UIView {
    var onSlot: ((Int) -> Void)?
    var onEmoji: ((String) -> Void)?
    var onCloseSearch: (() -> Void)?

    private let slots = UIStackView()
    private var slotButtons: [UIButton] = []
    private let search = UIStackView()
    private let queryLabel = UILabel()
    private let results = UIScrollView()
    private let resultsStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        slots.distribution = .fillEqually
        for i in 0..<3 {
            let b = UIButton(type: .custom)
            b.titleLabel?.font = .systemFont(ofSize: 17)
            b.titleLabel?.lineBreakMode = .byTruncatingMiddle
            b.setTitleColor(.label, for: .normal)
            b.layer.cornerRadius = 8
            b.layer.cornerCurve = .continuous
            b.addAction(UIAction { [weak self] _ in self?.onSlot?(i) }, for: .touchUpInside)
            slotButtons.append(b)
            slots.addArrangedSubview(b)
        }

        queryLabel.font = .systemFont(ofSize: 16)
        queryLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        resultsStack.spacing = 2
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        results.showsHorizontalScrollIndicator = false
        results.addSubview(resultsStack)
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .secondaryLabel
        close.widthAnchor.constraint(equalToConstant: 40).isActive = true
        close.addAction(UIAction { [weak self] _ in self?.onCloseSearch?() }, for: .touchUpInside)
        search.spacing = 6
        [queryLabel, results, close].forEach { search.addArrangedSubview($0) }
        search.isHidden = true

        for v in [slots, search] as [UIView] {
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

    /// `highlighted`: the slot space will pick (autocorrect), drawn like a key.
    func show(_ texts: [String?], highlighted: Int?) {
        slots.isHidden = false
        search.isHidden = true
        for (i, b) in slotButtons.enumerated() {
            let text = i < texts.count ? texts[i] : nil
            b.setTitle(text, for: .normal)
            b.isEnabled = text != nil
            b.backgroundColor = i == highlighted ? KeyStyle.letterKey : .clear
        }
    }

    func showSearch(query: String, emoji: [String]) {
        slots.isHidden = true
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
