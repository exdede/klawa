import UIKit

/// Button for the emoji, clipboard and snippets panels. Its whole area takes touches (keyboards ignore
/// touches on fully clear pixels); with `repeats` it fires again while held, like the backspace key.
final class PanelButton: UIButton {
    private var action: () -> Void = {}
    private var timer: Timer?

    static func make(title: String? = nil, symbol: String? = nil, fontSize: CGFloat = 15, repeats: Bool = false,
                     action: @escaping () -> Void) -> PanelButton {
        let b = PanelButton(type: .system)
        b.action = action
        b.setTitle(title, for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: fontSize)
        if let symbol { b.setImage(UIImage(systemName: symbol), for: .normal) }
        b.tintColor = .label
        b.backgroundColor = KeyStyle.touchable
        if repeats {
            b.addTarget(b, action: #selector(down), for: .touchDown)
            b.addTarget(b, action: #selector(up), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        } else {
            b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        return b
    }

    @objc private func down() {
        action()
        var ticks = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            ticks += 1
            if ticks > 5 { self?.action() } // starts after ~0.45 s
        }
    }

    @objc private func up() {
        timer?.invalidate()
        timer = nil
    }
}
