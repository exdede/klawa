import UIKit

/// Phase 0 throwaway keyboard: proves install, Full Access, globe and App Group on the phone.
final class KeyboardViewController: UIInputViewController {
    private var shifted = true
    private var letterButtons: [UIButton] = []
    private let statusLabel = UILabel()
    private lazy var globeButton = key("🌐", width: 44) { _ in }

    override func viewDidLoad() {
        super.viewDidLoad()

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        let letterRows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map { row in
            row.map { ch -> UIButton in
                let b = key(String(ch)) { [weak self] b in self?.type(b.currentTitle ?? "") }
                letterButtons.append(b)
                return b
            }
        }

        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let rows: [[UIView]] = [
            letterRows[0],
            letterRows[1],
            [key("⇧", width: 44) { [weak self] _ in self?.setShift(!(self?.shifted ?? false)) }]
                + letterRows[2]
                + [key("⌫", width: 44) { [weak self] _ in self?.textDocumentProxy.deleteBackward() }],
            [globeButton,
             key("spacja") { [weak self] _ in self?.textDocumentProxy.insertText(" ") },
             key("⏎", width: 88) { [weak self] _ in self?.textDocumentProxy.insertText("\n") }],
        ]

        let stack = UIStackView(arrangedSubviews: [statusLabel] + rows.map(row))
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
        setShift(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let defaults = AppGroup.defaults
        defaults?.set(Date(), forKey: "lastSeen")
        defaults?.set(hasFullAccess, forKey: "hasFullAccess")
        statusLabel.text = "Klawa etap 0 · Pełny dostęp: \(hasFullAccess ? "tak" : "nie") · grupa: \(defaults == nil ? "BRAK" : "ok")"
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globeButton.isHidden = !needsInputModeSwitchKey
    }

    private func type(_ text: String) {
        textDocumentProxy.insertText(text)
        if shifted { setShift(false) }
    }

    private func setShift(_ on: Bool) {
        shifted = on
        for b in letterButtons {
            let t = b.currentTitle ?? ""
            b.setTitle(on ? t.uppercased() : t.lowercased(), for: .normal)
        }
    }

    private func row(_ keys: [UIView]) -> UIStackView {
        let s = UIStackView(arrangedSubviews: keys)
        s.spacing = 6
        s.distribution = .fill
        // letter keys share the remaining width equally
        let flexible = keys.filter { $0.constraints.allSatisfy { $0.firstAttribute != .width } }
        for k in flexible.dropFirst() { k.widthAnchor.constraint(equalTo: flexible[0].widthAnchor).isActive = true }
        return s
    }

    private func key(_ title: String, width: CGFloat? = nil, action: @escaping (UIButton) -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22)
        b.setTitleColor(.label, for: .normal)
        b.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
        b.layer.cornerRadius = 6
        b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if let width { b.widthAnchor.constraint(equalToConstant: width).isActive = true }
        b.addAction(UIAction { a in action(a.sender as! UIButton) }, for: .touchUpInside)
        return b
    }
}
