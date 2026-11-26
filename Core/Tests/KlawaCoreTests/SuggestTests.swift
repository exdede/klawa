import XCTest
import KlawaCore

final class SuggestTests: XCTestCase {
    // deliberately unsorted: the lexicon sorts what is out of order
    static let lexicon = Lexicon(text: """
    the\te\t1000
    I\te\t900
    I'm\te\t300
    i\tp\t800
    im\tp\t200
    ze\tp\t400
    że\tp\t3000
    żółw\tp\t50
    się\tp\t5000
    pies\tp\t100
    dzięki\tp\t500
    dziękuję\tp\t400
    dzień\tp\t600
    """)
    let s = Suggester(lexicon: SuggestTests.lexicon, layout: .qwerty)

    func suggest(_ typed: String, _ language: LanguageMode = .pl, user: UserWords = UserWords()) -> Suggestions {
        s.suggest(typed: typed, previous: nil, language: language, user: user)
    }

    func testFold() {
        XCTAssertEqual(Lexicon.fold("Żółw"), "zolw")
        XCTAssertEqual(Lexicon.fold("Don't"), "dont")
        XCTAssertTrue(Self.lexicon.contains("Żółw"))
        XCTAssertFalse(Self.lexicon.contains("zolw"))
        XCTAssertEqual(Self.lexicon.count, 13)
    }

    func testMissingPolishLettersAreCorrected() {
        XCTAssertEqual(suggest("zolw").autocorrect, "żółw")
        XCTAssertEqual(suggest("Zolw").autocorrect, "Żółw")
        XCTAssertEqual(suggest("sie").autocorrect, "się")
    }

    func testKnownWordsStay() {
        let r = suggest("ze")
        XCTAssertNil(r.autocorrect)
        XCTAssertEqual(r.words.first, "że")
        XCTAssertFalse(r.words.contains("ze"))
        XCTAssertNil(suggest("i").autocorrect)
        XCTAssertNil(suggest("ZOLW").autocorrect) // caps lock = on purpose
    }

    func testTyposAndEnglish() {
        XCTAssertEqual(suggest("teh").autocorrect, "the")
        XCTAssertEqual(suggest("i", .en).autocorrect, "I")
        XCTAssertNil(suggest("xq").autocorrect)
    }

    func testCompletionsPreferTypedPolishLetters() {
        XCTAssertEqual(suggest("dzię").words.prefix(2), ["dzięki", "dziękuję"])
        XCTAssertNil(suggest("dzię").autocorrect)
    }

    func testLearnedWords() {
        var user = UserWords()
        user.learn("kotełek", after: nil)
        XCTAssertFalse(user.knows("kotełek"))
        user.learn("Kotełek", after: nil)
        XCTAssertTrue(user.knows("kotełek"))
        XCTAssertEqual(suggest("kote", user: user).words.first, "kotełek")
        user.learn("pies", after: "mój")
        XCTAssertEqual(s.suggest(typed: "", previous: "Mój", language: .pl, user: user).words, ["pies"])
    }

    func testOwnWords() {
        let own = ["Klawa"]
        func s(_ t: String) -> Suggestions { self.s.suggest(typed: t, previous: nil, language: .pl, user: UserWords(), custom: own) }
        XCTAssertEqual(s("klawa").autocorrect, "Klawa")
        XCTAssertNil(s("Klawa").autocorrect)
        XCTAssertEqual(s("Kla").words.first, "Klawa")
        XCTAssertEqual(s("Klaws").autocorrect, "Klawa")
    }

    func testCorpusNextWords() {
        var s = self.s
        s.next = NextWords(text: "p\tdzień\tdobry w\np\t<s>\tnie to\ne\t<s>\tI you\n")
        XCTAssertEqual(s.suggest(typed: "", previous: "Dzień", language: .pl, user: UserWords()).words, ["dobry", "w"])
        XCTAssertEqual(s.suggest(typed: "", previous: nil, language: .pl, user: UserWords()).words, ["nie", "to", "I"])
        var user = UserWords()
        user.learn("dzięki", after: "dzień")
        XCTAssertEqual(s.suggest(typed: "", previous: "dzień", language: .pl, user: user).words, ["dzięki", "dobry", "w"])
        // completions that fit after the previous word rank higher
        s.next = NextWords(text: "p\tbardzo\tdziękuję\n")
        XCTAssertEqual(s.suggest(typed: "dzię", previous: "bardzo", language: .pl, user: UserWords()).words.first, "dziękuję")
    }

    func testNextLetterMass() {
        let m = Self.lexicon.nextLetterMass(prefix: "dzi", letters: ["e", "x"], weights: [.pl: 1, .en: 0.5])!
        XCTAssertGreaterThan(m[0], 0)
        XCTAssertEqual(m[1], 0)
        XCTAssertNil(Self.lexicon.nextLetterMass(prefix: "qq", letters: ["a"], weights: [.pl: 1]))
    }

    func testNeighbors() {
        let n = letterNeighbors(.qwerty)
        XCTAssertTrue(n["s"]!.isSuperset(of: ["a", "d", "w", "e", "z", "x"]))
        XCTAssertFalse(n["s"]!.contains("p"))
    }
}

final class MathTests: XCTestCase {
    func r(_ s: String) -> MathEval.Result? { MathEval.result(contextBefore: s) }

    func testResults() {
        XCTAssertEqual(r("ile to 12*3")?.display, "= 36")
        XCTAssertEqual(r("ile to 12*3")?.insert, "=36")
        XCTAssertEqual(r("2,5×4=")?.insert, "10")
        XCTAssertEqual(r("2 + 2 =")?.insert, "4")
        XCTAssertEqual(r("10/4")?.display, "= 2.5")
        XCTAssertEqual(r("1,5+1")?.display, "= 2,5")
        XCTAssertEqual(r("(1+2)^2")?.display, "= 9")
        XCTAssertEqual(r("200*15%")?.display, "= 30")
    }

    func testNotMath() {
        XCTAssertNil(r("1/0"))
        XCTAssertNil(r("abc"))
        XCTAssertNil(r("-5"))
        XCTAssertNil(r("50%"))
        XCTAssertNil(r("25.11.2026"))
        XCTAssertNil(r("2+"))
    }
}

final class WordAndTouchTests: XCTestCase {
    func testCurrentAndPreviousWord() {
        XCTAssertEqual(TextOps.currentWord(contextBefore: "ala ma kot"), "kot")
        XCTAssertEqual(TextOps.currentWord(contextBefore: "hello "), "")
        XCTAssertEqual(TextOps.currentWord(contextBefore: "I don't"), "don't")
        XCTAssertEqual(TextOps.currentWord(contextBefore: "'quote"), "quote")
        XCTAssertEqual(TextOps.previousWord(contextBefore: "ala ma kot"), "ma")
        XCTAssertEqual(TextOps.previousWord(contextBefore: "ala ma "), "ma")
        XCTAssertNil(TextOps.previousWord(contextBefore: "ala. kot"))
    }

    func testTouchBias() {
        // key 0 at the touch, key 1 one pitch away and 1000x more likely: center touch keeps key 0
        XCTAssertEqual(TouchModel.pick(offsets: [(0, 0), (-1, 0)], masses: [0.001, 1]), 0)
        // touch on the border between them goes to the likely key
        XCTAssertEqual(TouchModel.pick(offsets: [(0.45, 0), (-0.55, 0)], masses: [0.001, 1]), 1)
        // a touch 0.3 pitch off center keeps its key even against 1000x odds (gentle bias)
        XCTAssertEqual(TouchModel.pick(offsets: [(0.3, 0), (-0.7, 0)], masses: [0.001, 1]), 0)
        // no odds: nearest key
        XCTAssertEqual(TouchModel.pick(offsets: [(0.45, 0), (-0.55, 0)], masses: [0, 0]), 0)
    }
}
