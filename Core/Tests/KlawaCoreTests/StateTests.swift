import XCTest
import KlawaCore

final class StateTests: XCTestCase {
    func testDoubleTapShiftIsCapsLock() {
        var s = KeyboardState()
        s.tapShift(at: 0)
        s.tapShift(at: 0.2)
        XCTAssertEqual(s.shift, .capsLock)
        s.typedCharacter()
        XCTAssertEqual(s.shift, .capsLock)
        s.tapShift(at: 5)
        XCTAssertEqual(s.shift, .off)
    }

    func testSlowSecondTapTurnsShiftOff() {
        var s = KeyboardState()
        s.tapShift(at: 0)
        s.tapShift(at: 1)
        XCTAssertEqual(s.shift, .off)
    }

    func testShiftIsOneShot() {
        var s = KeyboardState()
        XCTAssertEqual(s.shift, .off) // no auto-capitalization
        s.tapShift(at: 0)
        s.typedCharacter()
        XCTAssertEqual(s.shift, .off)
    }

    func testSpaceReturnsToLetters() {
        var s = KeyboardState()
        s.page = .numbers
        s.typedSpaceOrReturn()
        XCTAssertEqual(s.page, .letters)
    }

    func testLanguageCycle() {
        XCTAssertEqual(LanguageMode.pl.next, .en)
        XCTAssertEqual(LanguageMode.en.next, .pl)
        XCTAssertNil(LanguageMode(rawValue: "auto")) // old stored value falls back to the default
    }
}

final class TextOpsTests: XCTestCase {
    func testPeriod() {
        XCTAssertTrue(TextOps.shouldInsertPeriod(contextBefore: "hello ", lastSpaceAt: 0, now: 0.3))
        XCTAssertTrue(TextOps.shouldInsertPeriod(contextBefore: "mam 2 ", lastSpaceAt: 0, now: 0.3))
        XCTAssertFalse(TextOps.shouldInsertPeriod(contextBefore: "hello? ", lastSpaceAt: 0, now: 0.3))
        XCTAssertFalse(TextOps.shouldInsertPeriod(contextBefore: "koniec. ", lastSpaceAt: 0, now: 0.3))
        XCTAssertFalse(TextOps.shouldInsertPeriod(contextBefore: " ", lastSpaceAt: 0, now: 0.3))
        XCTAssertFalse(TextOps.shouldInsertPeriod(contextBefore: "hello ", lastSpaceAt: 0, now: 1.0))
        XCTAssertFalse(TextOps.shouldInsertPeriod(contextBefore: "hello ", lastSpaceAt: nil, now: 0.3))
    }

    func testWordDelete() {
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: "ala ma kota  "), 6)
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: "to 😀"), 1)
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: "wow!!!"), 3)
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: "zażółć"), 6)
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: ""), 0)
        XCTAssertEqual(TextOps.wordDeleteCount(contextBefore: nil), 0)
    }

    func testCursorOffsetKeepsWholeCharacters() {
        XCTAssertEqual(TextOps.cursorOffset(step: -1, contextBefore: "a😀", contextAfter: nil), -2)
        XCTAssertEqual(TextOps.cursorOffset(step: -1, contextBefore: "x👨‍👩‍👧", contextAfter: nil), -"👨‍👩‍👧".utf16.count)
        XCTAssertEqual(TextOps.cursorOffset(step: 1, contextBefore: nil, contextAfter: "ę"), 1)
        XCTAssertEqual(TextOps.cursorOffset(step: -5, contextBefore: "ab", contextAfter: nil), -2)
        XCTAssertEqual(TextOps.cursorOffset(step: -1, contextBefore: nil, contextAfter: "x"), -1)
        XCTAssertEqual(TextOps.cursorOffset(step: 2, contextBefore: nil, contextAfter: "😀b"), 3)
    }

    func testPopupStaysOnScreen() {
        XCTAssertEqual(PopupGeometry.originX(keyMidX: 5, popupWidth: 100, containerWidth: 390), 2)
        XCTAssertEqual(PopupGeometry.originX(keyMidX: 388, popupWidth: 100, containerWidth: 390), 288)
        XCTAssertEqual(PopupGeometry.originX(keyMidX: 200, popupWidth: 100, containerWidth: 390), 150)
    }

    func testAlternatesStartAboveFinger() {
        // left half: first cell (x 183...217) centered on the key, strip extends right
        XCTAssertEqual(PopupGeometry.alternatesOriginX(keyMidX: 200, popupWidth: 100, cellWidth: 34, pad: 4,
                                                       containerWidth: 430, rightToLeft: false), 179)
        // right half: first cell centered on the key, strip extends left
        XCTAssertEqual(PopupGeometry.alternatesOriginX(keyMidX: 355, popupWidth: 280, cellWidth: 34, pad: 4,
                                                       containerWidth: 430, rightToLeft: true), 96)
    }

    func testAlternateIndexIsRelative() {
        let pick = { (dx: Double, dy: Double, rtl: Bool) in
            PopupGeometry.alternateIndex(dx: dx, dy: dy, cellWidth: 34, cellHeight: 42, columns: 8, count: 17, rightToLeft: rtl)
        }
        XCTAssertEqual(pick(0, 0, false), 0)
        XCTAssertEqual(pick(12, 5, false), 0)   // finger wobble keeps the first option
        XCTAssertEqual(pick(40, 0, false), 1)
        XCTAssertEqual(pick(-40, 0, false), 0)
        XCTAssertEqual(pick(-40, 0, true), 1)
        XCTAssertEqual(pick(34, -45, false), 9) // up one row
        XCTAssertEqual(pick(200, -100, false), 16) // clamped to the last option
    }
}
