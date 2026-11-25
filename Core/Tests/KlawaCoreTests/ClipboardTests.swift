import XCTest
import KlawaCore

final class ClipboardTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testOrderPinAndExpiry() {
        var h = ClipboardHistory()
        h.add("a", at: t0)
        h.add("b", at: t0 + 10)
        h.add("  ", at: t0 + 20)
        XCTAssertEqual(h.clips.map(\.text), ["b", "a"])
        h.togglePin(1) // pin "a"
        XCTAssertEqual(h.clips.map(\.text), ["a", "b"])
        h.add("b", at: t0 + 30) // copied again: moves up, no duplicate
        XCTAssertEqual(h.clips.map(\.text), ["a", "b"])
        h.expire(now: t0 + 30 + ClipboardHistory.lifetime + 1)
        XCTAssertEqual(h.clips.map(\.text), ["a"]) // pinned stays
        h.add("c", at: t0)
        h.clearUnpinned()
        XCTAssertEqual(h.clips.map(\.text), ["a"])
        h.remove(0)
        XCTAssertTrue(h.clips.isEmpty)
    }

    func testLimit() {
        var h = ClipboardHistory()
        for i in 0..<40 { h.add("\(i)", at: t0 + Double(i)) }
        XCTAssertEqual(h.clips.count, 30)
        XCTAssertEqual(h.clips.first?.text, "39")
    }

    func testExtract() {
        let items = ClipExtract.items(in: "strona https://example.com/x oraz mail ala@example.com")
        XCTAssertTrue(items.contains("https://example.com/x"))
        XCTAssertTrue(items.contains("ala@example.com"))
        XCTAssertEqual(ClipExtract.items(in: "https://example.com"), []) // the whole clip is the link
    }
}
