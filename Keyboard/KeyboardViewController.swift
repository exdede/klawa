import UIKit
import KlawaCore

/// Input view that lets `playInputClick()` play the system keyboard click.
final class KlawaInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private var state = KeyboardState()
    private let keyboard = KeyboardView()
    private let topBar = UIView() // Phase 2: suggestions
    private var emojiPanel: EmojiPanel?
    private var layoutName = LayoutName.qwerty
    private var haptics = true
    private var languageMode = LanguageMode.auto
    private var lastSpaceAt: TimeInterval?
    private var lastKeyboardType: UIKeyboardType?
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private static let recentsKey = "emojiRecents"

    override func loadView() {
        let input = KlawaInputView(frame: .zero, inputViewStyle: .keyboard)
        input.allowsSelfSizing = true
        view = input
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for v in [topBar, keyboard] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let height = view.heightAnchor.constraint(equalToConstant: KeyStyle.keyboardHeight)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: KeyStyle.topBarHeight),
            keyboard.topAnchor.constraint(equalTo: topBar.bottomAnchor),
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSettings()
        hideEmoji()
        state = KeyboardState()
        lastKeyboardType = textDocumentProxy.keyboardType
        state.page = startPage()
        lastSpaceAt = nil
        feedback.prepare()
        refresh()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
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
        languageMode = d?.string(forKey: SettingsKey.languageMode).flatMap(LanguageMode.init(rawValue:)) ?? .auto
        applyLanguage()
    }

    private func applyLanguage() {
        // Hint for the system (e.g. Apple dictation); suggestions come in Phase 2.
        primaryLanguage = languageMode == .en ? "en-US" : "pl-PL"
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
        let language: (key: String, space: String)
        switch languageMode {
        case .auto: language = ("A", "PL · EN")
        case .pl: language = ("PL", "Polski")
        case .en: language = ("EN", "English")
        }
        keyboard.configure(rows: currentRows(), uppercase: state.page == .letters && state.shift != .off, shift: state.shift,
                           languageLabel: language.key, spaceLabel: language.space, returnLabel: returnLabel())
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
        textDocumentProxy.insertText(text)
        lastSpaceAt = nil
        let before = state.shift
        state.typedCharacter()
        if state.shift != before { refresh() }
    }

    private func handle(_ kind: KeyKind) {
        switch kind {
        case .space:
            let now = CACurrentMediaTime()
            if TextOps.shouldInsertPeriod(contextBefore: textDocumentProxy.documentContextBeforeInput, lastSpaceAt: lastSpaceAt, now: now) {
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                lastSpaceAt = nil
            } else {
                textDocumentProxy.insertText(" ")
                lastSpaceAt = now
            }
            state.typedSpaceOrReturn()
        case .returnKey:
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
            showEmoji()
            return
        case .character, .backspace, .globe:
            return
        }
        refresh()
    }

    private func backspace(_ unit: BackspaceUnit) {
        lastSpaceAt = nil
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
        panel.onEmoji = { [weak self] emoji in
            self?.press()
            self?.textDocumentProxy.insertText(emoji)
            let recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
            UserDefaults.standard.set(EmojiCatalog.addRecent(emoji, to: recents), forKey: Self.recentsKey)
        }
        panel.onBackspace = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        panel.onClose = { [weak self] in self?.hideEmoji() }
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: keyboard.topAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboard.isHidden = true
        emojiPanel = panel
    }

    private func hideEmoji() {
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        keyboard.isHidden = false
    }
}
