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

final class EmojiSearchTests: XCTestCase {
    let search = EmojiSearch(text: """
    ❤️\tczerwone|kocham|milosc|serce|czerwone serce|heart|love
    🐱\tkot|kotek|glowa kota|cat|cat face
    🐈\tkot|zwierze|cat
    🍕\tpizza|jedzenie|food
    """)

    func testSearch() {
        XCTAssertEqual(search.search("kot"), ["🐱", "🐈"])
        XCTAssertEqual(search.search("Miłość"), ["❤️"])
        XCTAssertEqual(search.search("czer ser"), ["❤️"])
        XCTAssertEqual(search.search("cat f"), ["🐱"])
        XCTAssertEqual(search.search(" "), [])
        XCTAssertEqual(search.search("xyz"), [])
    }
}
