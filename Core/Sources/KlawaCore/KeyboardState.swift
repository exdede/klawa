import Foundation

public enum ShiftState: Equatable {
    case off, on, capsLock
}

public enum LanguageMode: String, CaseIterable {
    case auto, pl, en

    public var next: LanguageMode {
        switch self {
        case .auto: return .pl
        case .pl: return .en
        case .en: return .auto
        }
    }
}

/// Shift and page state. No auto-capitalization: shift changes only on user taps.
public struct KeyboardState {
    public var page: Page = .letters
    public var shift: ShiftState = .off
    private var shiftTurnedOnAt: TimeInterval?

    public init() {}

    public mutating func tapShift(at time: TimeInterval) {
        switch shift {
        case .off:
            shift = .on
            shiftTurnedOnAt = time
        case .on:
            if let t = shiftTurnedOnAt, time - t <= 0.35 { shift = .capsLock } else { shift = .off }
            shiftTurnedOnAt = nil
        case .capsLock:
            shift = .off
        }
    }

    public mutating func typedCharacter() {
        if shift == .on { shift = .off }
    }

    /// Like iOS: space or return on the numbers/symbols page goes back to letters.
    public mutating func typedSpaceOrReturn() {
        page = .letters
    }
}
