import UIKit
import KlawaCore

/// Input view that lets `playInputClick()` play the system keyboard click.
final class KlawaInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private var state = KeyboardState()
    private let keyboard = KeyboardView()
    private let bar = SuggestionBar()
    private var emojiPanel: EmojiPanel?
    private var clipboardPanel: ClipboardPanel?
    private var snippetsPanel: SnippetsPanel?
    /// Copied texts; stays in the keyboard's own container, unpinned ones expire after an hour.
    private var clipboard = ClipboardHistory()
    /// Just copied and not pasted yet: offered in the suggestion bar.
    private var freshClip: String?
    private static let clipboardKey = "clipboard"
    private static let clipboardChangeKey = "clipboardChangeCount"
    private var layoutName = LayoutName.qwerty
    private var haptics = true
    private var autocorrect = true
    private var languageMode = LanguageMode.pl
    private var lastSpaceAt: TimeInterval?
    private var lastKeyboardType: UIKeyboardType?
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private static let recentsKey = "emojiRecents"
    private static let userWordsKey = "userWords"

    /// Loaded once per keyboard process, off the main thread.
    private static var lexicon: Lexicon?
    private static var lexiconLoading = false
    private static let emojiSearch = EmojiSearch(text: Bundle.main.url(forResource: "emoji-keywords", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "")
    private var suggester: Suggester?
    /// Learned words; stays in the keyboard's own container, never leaves the phone.
    private var userWords = UserWords()
    private var unsavedWords = 0
    private enum SlotAction { case word(String), keepTyped(String), math(String), paste(String) }
    private var slotActions: [SlotAction?] = []
    private var lastCorrection: (original: String, corrected: String)?
    /// Non-nil while typing an emoji search; keys then edit the query, not the document.
    private var searchQuery: String?
    private var suggestionsScheduled = false

    override func loadView() {
        let input = KlawaInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true
        view = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for v in [bar, keyboard] as [UIView] { // keyboard last: it takes touches a bit above its top
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let height = view.heightAnchor.constraint(equalToConstant: KeyStyle.keyboardHeight)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: KeyStyle.topBarHeight),
            keyboard.topAnchor.constraint(equalTo: bar.bottomAnchor),
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])

        keyboard.popupHost = view
        keyboard.onPress = { [weak self] in self?.press() }
        keyboard.onInsert = { [weak self] in self?.insert($0) }
        keyboard.onKey = { [weak self] in self?.handle($0) }
        keyboard.onBackspace = { [weak self] in self?.backspace($0) }
        keyboard.onCursorMove = { [weak self] in self?.moveCursor($0) }
        keyboard.onGlobe = { [weak self] view, event in self?.handleInputModeList(from: view, with: event) }
        keyboard.letterOdds = { [weak self] letters in self?.letterOdds(letters) }
        bar.onSlot = { [weak self] in self?.pickSlot($0) }
        bar.onEmoji = { [weak self] in self?.insertEmoji($0) }
        bar.onCloseSearch = { [weak self] in self?.closeSearch() }
        bar.onClipboard = { [weak self] in self?.showClipboard() }
        bar.onSnippets = { [weak self] in self?.showSnippets() }
        if let data = UserDefaults.standard.data(forKey: Self.clipboardKey),
           let saved = try? JSONDecoder().decode(ClipboardHistory.self, from: data) {
            clipboard = saved
        }
        if let data = UserDefaults.standard.data(forKey: Self.userWordsKey),
           let saved = try? JSONDecoder().decode(UserWords.self, from: data) {
            userWords = saved
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveUserWords()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        loadLexicon()
        hideEmoji()
        searchQuery = nil
        lastCorrection = nil
        clipboard.expire(now: Date())
        captureClipboard()
        state = KeyboardState()
        lastKeyboardType = textDocumentProxy.keyboardType
        state.page = startPage()
        lastSpaceAt = nil
        feedback.prepare()
        refresh()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        captureClipboard()
        if textDocumentProxy.keyboardType != lastKeyboardType {
            lastKeyboardType = textDocumentProxy.keyboardType
            state.page = startPage()
        }
        refresh()
    }

    // MARK: settings and layout

    private func loadSettings() {
        let d = AppGroup.defaults
        layoutName = d?.string(forKey: SettingsKey.layout).flatMap(LayoutName.init(rawValue:)) ?? .qwerty
        haptics = d?.object(forKey: SettingsKey.haptics) as? Bool ?? true
        autocorrect = d?.object(forKey: SettingsKey.autocorrect) as? Bool ?? true
        languageMode = d?.string(forKey: SettingsKey.languageMode).flatMap(LanguageMode.init(rawValue:)) ?? .pl
        applyLanguage()
    }

    private func applyLanguage() {
        // Sets the Apple dictation language (verified on the phone); suggestions also favor it.
        primaryLanguage = languageMode == .en ? "en-US" : "pl-PL"
    }

    private func loadLexicon() {
        if let lexicon = Self.lexicon {
            if suggester == nil || suggester?.neighbors != letterNeighbors(layoutName) {
                suggester = Suggester(lexicon: lexicon, layout: layoutName)
            }
            return
        }
        guard !Self.lexiconLoading else { return }
        Self.lexiconLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let lexicon = Bundle.main.url(forResource: "words", withExtension: "txt")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
                .map(Lexicon.init(text:))
            DispatchQueue.main.async { [weak self] in
                KeyboardViewController.lexicon = lexicon
                KeyboardViewController.lexiconLoading = false
                guard let self, lexicon != nil else { return }
                self.loadLexicon()
                self.scheduleSuggestions()
            }
        }
    }

    /// Normal text, where the host did not turn autocorrection off (not email, URL, login...).
    private var plainText: Bool {
        let type = textDocumentProxy.keyboardType ?? .default
        return type != .emailAddress && type != .URL && textDocumentProxy.autocorrectionType != .no
    }

    private func saveUserWords() {
        guard unsavedWords > 0, let data = try? JSONEncoder().encode(userWords) else { return }
        UserDefaults.standard.set(data, forKey: Self.userWordsKey)
        unsavedWords = 0
    }

    private func learn(_ word: String, after previous: String?, times: Int = 1) {
        guard plainText else { return }
        userWords.learn(word, after: previous, times: times)
        unsavedWords += 1
        if unsavedWords >= 10 { saveUserWords() }
    }

    private func startPage() -> Page {
        let numeric: [UIKeyboardType] = [.numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad, .numbersAndPunctuation]
        return numeric.contains(textDocumentProxy.keyboardType ?? .default) ? .numbers : .letters
    }

    private func currentRows() -> [[Key]] {
        var rows = keyRows(layoutName, page: state.page)
        var bottom = rows[3]
        var spaceDelta = 0.0
        if let dot = bottom.firstIndex(where: { $0.kind == .character(".") }) {
            switch textDocumentProxy.keyboardType ?? .default {
            case .emailAddress:
                bottom.insert(Key(.character("@")), at: dot)
                spaceDelta += 1
            case .URL:
                bottom.insert(Key(.character("/"), alternates: [".com", ".pl", ".org", ".net"]), at: dot)
                spaceDelta += 1
            default:
                break
            }
        }
        if needsInputModeSwitchKey {
            bottom.insert(Key(.globe, width: 1.1), at: 1)
            spaceDelta += 1.1
        }
        if spaceDelta > 0, let s = bottom.firstIndex(where: { $0.kind == .space }) {
            bottom[s] = Key(.space, width: bottom[s].width - spaceDelta)
        }
        rows[3] = bottom
        return rows
    }

    private func refresh() {
        let language = languageMode == .pl ? (key: "PL", space: "Polski") : (key: "EN", space: "English")
        keyboard.configure(rows: currentRows(), uppercase: state.page == .letters && state.shift != .off, shift: state.shift,
                           languageLabel: language.key, spaceLabel: language.space, returnLabel: returnLabel())
        scheduleSuggestions()
    }

    // MARK: suggestions

    /// One update per run-loop pass, however many keys changed the text.
    private func scheduleSuggestions() {
        guard !suggestionsScheduled else { return }
        suggestionsScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.suggestionsScheduled = false
            self?.updateSuggestions()
        }
    }

    private func updateSuggestions() {
        if let q = searchQuery {
            bar.showSearch(query: q, emoji: Self.emojiSearch.search(q))
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput
        if let math = MathEval.result(contextBefore: before) {
            slotActions = [nil, .math(math.insert), nil]
            bar.show([nil, math.display, nil], highlighted: nil)
            return
        }
        guard let suggester else {
            slotActions = []
            bar.show([], highlighted: nil)
            return
        }
        let typed = TextOps.currentWord(contextBefore: before)
        if typed.isEmpty, let clip = freshClip {
            let extracted = ClipExtract.items(in: clip)
            slotActions = [extracted.first.map { SlotAction.paste($0) }, .paste(clip), extracted.dropFirst().first.map { SlotAction.paste($0) }]
            bar.show([extracted.first, "📋 " + clip.trimmingCharacters(in: .whitespacesAndNewlines), extracted.dropFirst().first], highlighted: nil)
            return
        }
        let s = suggester.suggest(typed: typed, previous: TextOps.previousWord(contextBefore: before),
                                  language: languageMode, user: userWords)
        let fix = autocorrect && plainText ? s.autocorrect : nil
        let w = s.words
        if typed.isEmpty {
            slotActions = [w.count > 1 ? .word(w[1]) : nil, w.first.map { SlotAction.word($0) }, w.count > 2 ? .word(w[2]) : nil]
        } else {
            let middle = fix ?? w.first
            slotActions = [.keepTyped(typed), middle.map { SlotAction.word($0) }, w.first { $0 != middle }.map { SlotAction.word($0) }]
        }
        bar.show(slotActions.map { action -> String? in
            switch action {
            case .word(let w)?: return w
            case .keepTyped(let t)?: return "“\(t)”"
            case .math?, .paste?, nil: return nil
            }
        }, highlighted: fix != nil ? 1 : nil)
    }

    private func pickSlot(_ i: Int) {
        guard i < slotActions.count, let action = slotActions[i] else { return }
        press()
        let before = textDocumentProxy.documentContextBeforeInput
        let typed = TextOps.currentWord(contextBefore: before)
        let previous = TextOps.previousWord(contextBefore: before)
        lastCorrection = nil
        lastSpaceAt = nil
        switch action {
        case .math(let s):
            textDocumentProxy.insertText(s)
        case .paste(let s):
            textDocumentProxy.insertText(s)
            freshClip = nil
        case .keepTyped(let t):
            textDocumentProxy.insertText(" ")
            learn(t, after: previous, times: 2) // chosen as typed: never autocorrect it again
        case .word(let w):
            for _ in typed { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(w + " ")
            learn(w, after: previous)
        }
        state.typedCharacter()
        refresh()
    }

    /// Before space, return or punctuation: autocorrect the word just typed, then learn it.
    private func finishWord() {
        let before = textDocumentProxy.documentContextBeforeInput
        let typed = TextOps.currentWord(contextBefore: before)
        guard !typed.isEmpty else { return }
        let previous = TextOps.previousWord(contextBefore: before)
        var word = typed
        if autocorrect, plainText, let suggester,
           let fix = suggester.suggest(typed: typed, previous: previous, language: languageMode, user: userWords).autocorrect {
            for _ in typed { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(fix)
            lastCorrection = (typed, fix)
            word = fix
        }
        learn(word, after: previous)
    }

    private func letterOdds(_ letters: [String]) -> [Double]? {
        guard searchQuery == nil, plainText, let lexicon = Self.lexicon else { return nil }
        let prefix = Lexicon.fold(TextOps.currentWord(contextBefore: textDocumentProxy.documentContextBeforeInput))
        let weights: [LanguageMode: Double] = languageMode == .pl ? [.pl: 1, .en: 0.4] : [.en: 1, .pl: 0.4]
        return lexicon.nextLetterMass(prefix: prefix, letters: letters, weights: weights)
    }

    private func returnLabel() -> String? {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return "go"
        case .google, .yahoo, .search: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .continue: return "continue"
        case .emergencyCall: return "SOS"
        default: return nil
        }
    }

    // MARK: actions

    private func press() {
        if haptics && hasFullAccess { feedback.impactOccurred() }
        UIDevice.current.playInputClick()
    }

    private func insert(_ text: String) {
        if searchQuery != nil {
            searchQuery! += text.lowercased()
            scheduleSuggestions()
            return
        }
        lastCorrection = nil
        freshClip = nil // typing on: the paste offer goes away
        if [".", ",", "?", "!", ":", ";"].contains(text) { finishWord() }
        textDocumentProxy.insertText(text)
        lastSpaceAt = nil
        let before = state.shift
        state.typedCharacter()
        if state.shift != before { refresh() } else { scheduleSuggestions() }
    }

    private func handle(_ kind: KeyKind) {
        switch kind {
        case .space where searchQuery != nil:
            searchQuery! += " "
        case .returnKey where searchQuery != nil:
            searchQuery = nil
        case .space:
            let now = CACurrentMediaTime()
            if TextOps.shouldInsertPeriod(contextBefore: textDocumentProxy.documentContextBeforeInput, lastSpaceAt: lastSpaceAt, now: now) {
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                lastSpaceAt = nil
                lastCorrection = nil
            } else {
                lastCorrection = nil
                finishWord()
                textDocumentProxy.insertText(" ")
                lastSpaceAt = now
            }
            state.typedSpaceOrReturn()
        case .returnKey:
            lastCorrection = nil
            finishWord()
            lastCorrection = nil
            textDocumentProxy.insertText("\n")
            lastSpaceAt = nil
            state.typedSpaceOrReturn()
        case .shift:
            state.tapShift(at: CACurrentMediaTime())
        case .pageNumbers:
            state.page = .numbers
        case .pageSymbols:
            state.page = .symbols
        case .pageLetters:
            state.page = .letters
        case .language:
            languageMode = languageMode.next
            AppGroup.defaults?.set(languageMode.rawValue, forKey: SettingsKey.languageMode)
            applyLanguage()
        case .emoji:
            searchQuery = nil
            showEmoji()
            return
        case .character, .backspace, .globe:
            return
        }
        refresh()
    }

    private func backspace(_ unit: BackspaceUnit) {
        lastSpaceAt = nil
        if searchQuery != nil {
            if !searchQuery!.isEmpty { searchQuery!.removeLast() }
            scheduleSuggestions()
            return
        }
        // right after an autocorrection: put back what was typed
        if unit == .character, let c = lastCorrection,
           (textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(c.corrected + " ") {
            for _ in 0...c.corrected.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(c.original)
            learn(c.original, after: nil, times: 2)
            lastCorrection = nil
            scheduleSuggestions()
            return
        }
        lastCorrection = nil
        defer { scheduleSuggestions() }
        let count = unit == .word ? max(1, TextOps.wordDeleteCount(contextBefore: textDocumentProxy.documentContextBeforeInput)) : 1
        for _ in 0..<count { textDocumentProxy.deleteBackward() }
    }

    private func moveCursor(_ steps: Int) {
        let offset = TextOps.cursorOffset(step: steps,
                                          contextBefore: textDocumentProxy.documentContextBeforeInput,
                                          contextAfter: textDocumentProxy.documentContextAfterInput)
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    // MARK: emoji

    private func showEmoji() {
        let panel = EmojiPanel(recents: UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? [])
        panel.onEmoji = { [weak self] in self?.insertEmoji($0) }
        panel.onBackspace = { [weak self] in
            self?.textDocumentProxy.deleteBackward()
            self?.scheduleSuggestions()
        }
        panel.onClose = { [weak self] in self?.hideEmoji() }
        panel.onSearch = { [weak self] in self?.openSearch() }
        hideEmoji()
        show(panel)
        emojiPanel = panel
    }

    private func insertEmoji(_ emoji: String) {
        press()
        lastCorrection = nil
        textDocumentProxy.insertText(emoji)
        let recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        UserDefaults.standard.set(EmojiCatalog.addRecent(emoji, to: recents), forKey: Self.recentsKey)
        scheduleSuggestions()
    }

    private func openSearch() {
        hideEmoji()
        searchQuery = ""
        state.page = .letters
        refresh()
    }

    private func closeSearch() {
        searchQuery = nil
        refresh()
    }

    // MARK: clipboard

    /// Records a new copy. Skips what password managers mark as secret.
    private func captureClipboard() {
        guard hasFullAccess else { return }
        let pb = UIPasteboard.general
        let last = UserDefaults.standard.object(forKey: Self.clipboardChangeKey) as? Int
        guard pb.changeCount != last else { return }
        UserDefaults.standard.set(pb.changeCount, forKey: Self.clipboardChangeKey)
        let secret = pb.types.contains { type in
            ["Concealed", "Transient", "AutoGenerated"].contains { type == "org.nspasteboard.\($0)Type" }
        }
        guard last != nil, !secret, pb.hasStrings, let text = pb.string else { return }
        clipboard.add(text, at: Date())
        saveClipboard()
        freshClip = text
        scheduleSuggestions()
    }

    private func saveClipboard() {
        if let data = try? JSONEncoder().encode(clipboard) { UserDefaults.standard.set(data, forKey: Self.clipboardKey) }
    }

    private func showClipboard() {
        hideEmoji()
        searchQuery = nil
        clipboard.expire(now: Date())
        let panel = ClipboardPanel(history: clipboard, fullAccess: hasFullAccess)
        panel.onPaste = { [weak self] text in
            self?.press()
            self?.textDocumentProxy.insertText(text)
            self?.freshClip = nil
        }
        panel.onBackspace = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        panel.onClose = { [weak self] in
            self?.hideEmoji()
            self?.refresh()
        }
        panel.onChange = { [weak self] history in
            self?.clipboard = history
            self?.saveClipboard()
        }
        show(panel)
        clipboardPanel = panel
    }

    private func showSnippets() {
        hideEmoji()
        searchQuery = nil
        let panel = SnippetsPanel(fullAccess: hasFullAccess)
        panel.onInsert = { [weak self] text in
            self?.press()
            self?.textDocumentProxy.insertText(text)
        }
        panel.onBackspace = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        panel.onClose = { [weak self] in
            self?.hideEmoji()
            self?.refresh()
        }
        show(panel)
        snippetsPanel = panel
    }

    private func show(_ panel: UIView) {
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: keyboard.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboard.isHidden = true
    }

    /// Back to the keys from the emoji, clipboard or snippets panel.
    private func hideEmoji() {
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        clipboardPanel?.removeFromSuperview()
        clipboardPanel = nil
        snippetsPanel?.removeFromSuperview()
        snippetsPanel = nil
        keyboard.isHidden = false
    }
}
