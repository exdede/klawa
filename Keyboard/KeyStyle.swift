import UIKit

/// iOS-like key metrics and colors.
enum KeyStyle {
    static let keyHeight: CGFloat = 45
    static let rowGap: CGFloat = 11
    static let keyGap: CGFloat = 6
    static let sideMargin: CGFloat = 6
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 4
    static let topBarHeight: CGFloat = 44
    static let cornerRadius: CGFloat = 8
    static var keysHeight: CGFloat { topPadding + 4 * keyHeight + 3 * rowGap + bottomPadding }
    static var keyboardHeight: CGFloat { topBarHeight + keysHeight }

    /// Almost clear: keyboard extensions get no touches where pixels are fully transparent.
    static let touchable = UIColor(white: 0.5, alpha: 0.01)

    // Dark: measured on the owner's iOS 26 screenshot, every key is 68/255 over the 32/255 glass,
    // i.e. white at 16% over the system background, so the glass tint shows through like Apple's.
    static let letterKey = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : .white }
    // shortcut: light colors are still a guess; match them to a light-mode screenshot when one comes
    static let functionKey = UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : UIColor(white: 1, alpha: 0.55)
    }
    static let pressedKey = UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.4) : UIColor(white: 0.78, alpha: 1)
    }
    /// Opaque, so the keys under a press bubble or alternates strip don't show through it.
    static let popupKey = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.3, alpha: 1) : .white }
    /// Suggestion text: Apple draws it grey, not full white.
    static let barText = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.75) : UIColor(white: 0, alpha: 0.75) }

    static func applyShadow(_ layer: CALayer, bounds: CGRect, traits: UITraitCollection) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = traits.userInterfaceStyle == .dark ? 0 : 0.15
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
}
