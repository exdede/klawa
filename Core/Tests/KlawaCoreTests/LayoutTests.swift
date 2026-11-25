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
        XCTAssertEqual(e.alternates, ["ę", "3", "é", "è", "ê", "ë", "ė"])
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[0][8].alternates.prefix(2), ["ó", "9"])
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[0][6].alternates.first, "7") // u: no Polish letter
        XCTAssertEqual(e.hint, "3")
        XCTAssertEqual(keyRows(.qwerty, page: .letters)[0][9].hint, "0")
    }

    func testColemakTopRow() {
        let rows = keyRows(.colemak, page: .letters)
        XCTAssertEqual(rows[0].map(\.kind), "qwfpgjluy".map { KeyKind.character(String($0)) })
        XCTAssertEqual(rows[0].reduce(0) { $0 + $1.width }, 10, accuracy: 0.001)
        XCTAssertEqual(rows[1].count, 10)
        XCTAssertEqual(rows[0][8].alternates.prefix(2), ["9", "0"])
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

    func testNumbersPage() {
        let rows = keyRows(.qwerty, page: .numbers)
        let all = rows.flatMap { $0 }
        for s in ["zł", "$", "_", "#", "@"] { XCTAssertTrue(all.contains { $0.kind == .character(s) }, s) }
        XCTAssertEqual(all.first { $0.kind == .character("$") }?.alternates.first, "¢")
        XCTAssertTrue(keyRows(.qwerty, page: .symbols).flatMap { $0 }.contains { $0.kind == .character("&") })
    }
}
