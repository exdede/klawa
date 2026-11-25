import UIKit
import KlawaCore

/// Clipboard history in place of the keys: tap pastes, swipe left pins or deletes.
/// Links, emails and phone numbers found in a clip get their own rows below it.
final class ClipboardPanel: UIView, UITableViewDataSource, UITableViewDelegate {
    var onPaste: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onBackspace: (() -> Void)?
    var onChange: ((ClipboardHistory) -> Void)?

    private var history: ClipboardHistory
    private var rows: [(text: String, clip: Int?)] = []
    private let table = UITableView(frame: .zero, style: .plain)
    private let note = UILabel()

    init(history: ClipboardHistory, fullAccess: Bool) {
        self.history = history
        super.init(frame: .zero)
        backgroundColor = KeyStyle.touchable
        table.backgroundColor = KeyStyle.touchable
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        note.textAlignment = .center
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 15)
        note.textColor = .secondaryLabel
        note.text = fullAccess ? "Skopiuj coś, a pojawi się tutaj.\nNiezapięte znikają po godzinie."
            : "Schowek wymaga „Allow Full Access” w ustawieniach klawiatury."

        let bar = UIStackView()
        bar.distribution = .fillEqually
        bar.addArrangedSubview(PanelButton.make(title: "ABC") { [weak self] in self?.onClose?() })
        bar.addArrangedSubview(PanelButton.make(title: "Wyczyść") { [weak self] in
            self?.history.clearUnpinned()
            self?.changed()
        })
        bar.addArrangedSubview(PanelButton.make(symbol: "delete.left", repeats: true) { [weak self] in self?.onBackspace?() })

        for v in [table, note, bar] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: topAnchor),
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
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func reload() {
        rows = []
        for (i, clip) in history.clips.enumerated() {
            rows.append((clip.text, i as Int?))
            for item in ClipExtract.items(in: clip.text) { rows.append((item, nil)) }
        }
        note.isHidden = !rows.isEmpty
        table.reloadData()
    }

    private func changed() {
        reload()
        onChange?(history)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        let row = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
        content.textProperties.numberOfLines = 2
        if let i = row.clip {
            content.image = history.clips[i].pinned ? UIImage(systemName: "pin.fill") : nil
        } else {
            content.image = UIImage(systemName: "arrow.turn.down.right")
            content.textProperties.color = .link
            content.directionalLayoutMargins.leading = 28
        }
        cell.contentConfiguration = content
        cell.backgroundColor = KeyStyle.touchable
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onPaste?(rows[indexPath.row].text)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let i = rows[indexPath.row].clip else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Usuń") { [weak self] _, _, done in
            self?.history.remove(i)
            self?.changed()
            done(true)
        }
        let pin = UIContextualAction(style: .normal, title: history.clips[i].pinned ? "Odepnij" : "Przypnij") { [weak self] _, _, done in
            self?.history.togglePin(i)
            self?.changed()
            done(true)
        }
        pin.backgroundColor = .systemOrange
        return UISwipeActionsConfiguration(actions: [delete, pin])
    }
}
