import XCTest
import KlawaCore

final class EmojiTests: XCTestCase {
    func testParse() {
        let groups = EmojiCatalog.parse("Smileys\t😀 😃 👨‍👩‍👧\nFlags\t🇵🇱\n")
        XCTAssertEqual(groups.map(\.name), ["Smileys", "Flags"])
        XCTAssertEqual(groups[0].emojis, ["😀", "😃", "👨‍👩‍👧"])
        XCTAssertEqual(groups[1].emojis, ["🇵🇱"])
    }

    func testRecents() {
        XCTAssertEqual(EmojiCatalog.addRecent("😀", to: ["😂", "😀"]), ["😀", "😂"])
        XCTAssertEqual(EmojiCatalog.addRecent("❤️", to: ["a", "b", "c"], limit: 3), ["❤️", "a", "b"])
    }
}
