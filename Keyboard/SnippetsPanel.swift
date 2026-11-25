import UIKit

/// Saved texts by category in place of the keys: pick a category on top, tap a text to insert it.
final class SnippetsPanel: UIView, UITableViewDataSource, UITableViewDelegate {
    var onInsert: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onBackspace: (() -> Void)?

    private static let selectedKey = "snippetCategory"
    private let categories = Snippets.load()
    private var selected: Int
    private let tabs = UIStackView()
    private let table = UITableView(frame: .zero, style: .plain)
    private let note = UILabel()

    init(fullAccess: Bool) {
        selected = min(UserDefaults.standard.integer(forKey: Self.selectedKey), max(categories.count - 1, 0))
        super.init(frame: .zero)
        backgroundColor = KeyStyle.touchable
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.delaysContentTouches = false
        tabs.spacing = 6
        tabs.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(tabs)
        for (i, c) in categories.enumerated() {
            var config = UIButton.Configuration.gray()
            config.title = c.name
            config.cornerStyle = .capsule
            let b = UIButton(configuration: config)
            b.addAction(UIAction { [weak self] _ in self?.select(i) }, for: .touchUpInside)
            tabs.addArrangedSubview(b)
        }

        table.backgroundColor = KeyStyle.touchable
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        note.textAlignment = .center
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 15)
        note.textColor = .secondaryLabel
        note.text = fullAccess ? "Dodaj teksty w apce Klawa → Szybkie teksty."
            : "Szybkie teksty wymagają „Allow Full Access” w ustawieniach klawiatury."

        let bar = UIStackView()
        bar.distribution = .fillEqually
        bar.addArrangedSubview(PanelButton.make(title: "ABC") { [weak self] in self?.onClose?() })
        bar.addArrangedSubview(PanelButton.make(symbol: "delete.left", repeats: true) { [weak self] in self?.onBackspace?() })

        for v in [scroll, table, note, bar] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.heightAnchor.constraint(equalToConstant: 34),
            tabs.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            tabs.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            tabs.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            tabs.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            tabs.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            table.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            table.leadingAnchor.constraint(equalTo: leadingAnchor),
            table.trailingAnchor.constraint(equalTo: trailingAnchor),
            note.centerYAnchor.constraint(equalTo: table.centerYAnchor),
            note.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            note.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            bar.topAnchor.constraint(equalTo: table.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -KeyStyle.bottomPadding),
            bar.heightAnchor.constraint(equalToConstant: 40),
        ])
        select(selected)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var items: [Snippet] { categories.indices.contains(selected) ? categories[selected].items : [] }

    private func select(_ i: Int) {
        selected = i
        UserDefaults.standard.set(i, forKey: Self.selectedKey)
        for (j, v) in tabs.arrangedSubviews.enumerated() {
            guard let b = v as? UIButton else { continue }
            b.configuration?.baseBackgroundColor = j == i ? .systemBlue : nil
            b.configuration?.baseForegroundColor = j == i ? .white : .label
        }
        note.isHidden = !items.isEmpty
        table.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = items[indexPath.row].text
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        cell.backgroundColor = KeyStyle.touchable
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onInsert?(items[indexPath.row].text)
    }
}
