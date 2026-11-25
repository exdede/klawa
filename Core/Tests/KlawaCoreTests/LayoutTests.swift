import XCTest
import KlawaCore

final class LayoutTests: XCTestCase {
    func testRowWidthsFitTenUnits() {
        for layout in LayoutName.allCases {
            for page in [Page.letters, .numbers, .symbols] {
                for row in keyRows(layout, page: page) {
                    XCTAssertLessThanOrEqual(row.reduce(0) { $0 + $1.width }, 10.001, "\(layout) \(page)")
                }
                let bottom = keyRows(layout, page: page)[3]
                XCTAssertEqual(bottom.reduce(0) { $0 + $1.width }, 10, accuracy: 0.001)
            }
        }
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[0].reduce(0) { $0 + $1.width }, 10, accuracy: 0.001)
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[2].reduce(0) { $0 + $1.width }, 10, accuracy: 0.001)
    }

    func testTopRowDigitThenAccents() {
        let e = keyRows(.qwerty, page: .letters)[0][2]
        XCTAssertEqual(e.kind, .character("e"))
        XCTAssertEqual(e.alternates, ["3", "ę", "é", "è", "ê", "ë", "ė"])
        XCTAssertEqual(e.hint, "3")
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[0][9].hint, "0")
    }

    func testColemakTopRow() {
        let top = keyRows(.colemak, page: .letters)[0]
        XCTAssertEqual(top.count, 9)
        XCTAssertEqual(top[8].kind, .character("y"))
        XCTAssertEqual(top[8].alternates.first, "9")
        XCTAssertEqual(keyRows(.colemakDH, page: .letters)[2].map(\.kind),
                       [KeyKind.shift] + "zxcdvkh".map { KeyKind.character(String($0)) } + [KeyKind.backspace])
    }

    func testPolishLetterFirst() {
        for layout in LayoutName.allCases {
            let a = keyRows(layout, page: .letters).flatMap { $0 }.first { $0.kind == .character("a") }
            XCTAssertEqual(a?.alternates.first, "ą", "\(layout)")
        }
    }

    func testBottomRow() {
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[3].map(\.kind),
                       [.pageNumbers, .language, .emoji, .space, .character("."), .returnKey])
        XCTAssertEqual(keyRows(.qwerty, page: .numbers)[3].first?.kind, .pageLetters)
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[3][4].alternates.first, ",")
    }
}
