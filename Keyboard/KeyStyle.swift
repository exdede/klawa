import UIKit

/// iOS-like key metrics and colors.
enum KeyStyle {
    static let keyHeight: CGFloat = 46
    static let rowGap: CGFloat = 11
    static let keyGap: CGFloat = 6
    static let sideMargin: CGFloat = 6
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 4
    static let topBarHeight: CGFloat = 44
    static let cornerRadius: CGFloat = 10
    static var keysHeight: CGFloat { topPadding + 4 * keyHeight + 3 * rowGap + bottomPadding }
    static var keyboardHeight: CGFloat { topBarHeight + keysHeight }

    /// Almost clear: keyboard extensions get no touches where pixels are fully transparent.
    static let touchable = UIColor(white: 0.5, alpha: 0.01)

    static let letterKey = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    // shortcut: iOS 26-style guess (function keys close to letter keys); match to owner's screenshots when they come
    static let functionKey = UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 0.3, alpha: 1) : UIColor(white: 1, alpha: 0.55)
    }
    static let pressedKey = UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.78, alpha: 1)
    }

    static func applyShadow(_ layer: CALayer, bounds: CGRect, traits: UITraitCollection) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = traits.userInterfaceStyle == .dark ? 0 : 0.15
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
}
