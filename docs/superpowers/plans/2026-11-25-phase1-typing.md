# Phase 1 — Typing Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the throwaway keyboard with the real typing keyboard: iOS look, QWERTY/Colemak/Colemak-DH, Gboard-style long-press, shift/caps, number/symbol pages, emoji panel, cursor drag, backspace repeat, settings.

**Architecture:** Pure logic (layouts, long-press maps, shift/page state, double-space, word delete, cursor offsets, emoji catalog) lives in Swift package `KlawaCore` (no UIKit), tested by `swift test` on CI. The keyboard extension is one custom `KeyboardView` that lays out key frames and handles raw touches itself (no `UIButton`s) for iOS-like precision and multitouch. Emoji panel is a `UICollectionView`. Settings go through the App Group (verified working in Phase 0).

**Tech Stack:** Swift 5, UIKit, SwiftUI (app), SwiftPM local package via XcodeGen, GitHub Actions `macos-latest`.

**Spec:** `docs/superpowers/specs/2026-11-24-iphone-keyboard-design.md` (Goals 2, 4, 5, 6; Phase 1).

## Global Constraints

- No auto-capitalization anywhere. Shift is manual only (owner's choice).
- Bottom row: `123 | lang | emoji | space | . | return`.
- Language key cycles `A → PL → EN → A`; in Phase 1 it only stores the mode, sets `primaryLanguage` (`pl-PL` for A/PL, `en-US` for EN) and labels the space bar (`PL · EN`, `Polski`, `English`).
- Key labels in English where text is needed (phone UI is English); space shows the language label.
- Keyboard-owned data (emoji recents) in the extension's own `UserDefaults.standard`; settings in `AppGroup.defaults` with keys `layout` (`qwerty|colemak|colemakDH`, default `qwerty`), `haptics` (Bool, default `true`), `languageMode` (`auto|pl|en`, default `auto`).
- A 44 pt top bar sits above the keys (Phase 2 puts suggestions there). It gives room for key popups of the top row, which can't draw outside the keyboard.
- Nothing typed is logged or stored, except emoji recents.

## Review Focus

1. Fast two-thumb typing: a second finger lands before the first lifts. Both characters must be inserted, in touch-down order, each on touch-up of its own finger. → `KeyboardView` tracks touches per `UITouch`; checked on the phone (no UI test harness).
2. Cursor drag across emoji / Polish letters: moving one step must jump a whole character, never split a surrogate pair or ZWJ sequence. → `TextOps.cursorOffset` tests.
3. Word-delete on held backspace with emoji and punctuation before the cursor. → `TextOps.wordDeleteCount` tests.
4. Double space after `?`, `!`, `.`, or at start of text must NOT produce `. `. → `TextOps.shouldInsertPeriod` tests.
5. Long-press popup on the left-most / right-most key stays fully on screen. → `PopupGeometry.originX` tests.

---

### Task 1: KlawaCore package — layouts and long-press maps

**Files:**
- Create: `Core/Package.swift` (product `KlawaCore`, platforms iOS 17 / macOS 14)
- Create: `Core/Sources/KlawaCore/Layout.swift`
- Test: `Core/Tests/KlawaCoreTests/LayoutTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum LayoutName: String, CaseIterable { case qwerty, colemak, colemakDH }
  public enum Page { case letters, numbers, symbols }
  public enum KeyKind: Equatable { case character(String), shift, backspace, pageNumbers, pageSymbols, pageLetters, language, emoji, globe, space, returnKey }
  public struct Key: Equatable { public let kind: KeyKind; public let width: Double; public let alternates: [String]; public let hint: String? }
  public func keyRows(_ layout: LayoutName, page: Page) -> [[Key]]   // 4 rows, each sums to 10.0 width units
  ```
- Letter rows: QWERTY `qwertyuiop / asdfghjkl / zxcvbnm`; Colemak `qwfpgjluy / arstdhneio / zxcvbkm`; Colemak-DH `qwfpbjluy / arstgmneio / zxcdvkh` (`;` dropped on mobile — Claude's call). Row 3 = shift(1.5) + letters + backspace(1.5). Letter width is always 1.0; the view centers rows shorter than 10.
- Bottom row (all pages): pageNumbers/pageLetters `1.2`, language `1.1`, emoji `1.1`, space `3.6`, `.` `1.0`, return `2.0`.
- Numbers page: `1234567890` / `- / : ; ( ) zł & @ "` / pageSymbols(1.5) `. , ? ! '` (1.4 each) backspace(1.5). Symbols page: `[ ] { } # % ^ * + =` / `_ \ | ~ < > € $ £ •` / pageNumbers(1.5) `. , ? ! '` backspace(1.5).
- Alternates: top letter row key at index i gets digit `(i+1) % 10` first and `hint` = that digit. Accents table: `a ąáàâäãåæ · c ćčç · e ęéèêëė · l ł · n ńñ · o óöôòõøœ · s śšß · z żźž · u üúûù · i íïîì · y ýÿ`. `.` key: `, ? ! ' " - : ; ( ) @ / … & % #`. Numbers page: `-` → `– — •`, `"` → `„ ” « »`, `'` → `‘ ’`, `zł` → `$ € £ ¥`, `0` → `°`, `?` → `¿`, `!` → `¡`, `&` → `§`.

- [ ] Step 1: tests — every `keyRows(layout, page:)` row width sums to `10.0` ± 0.001 (rows with fewer letters excepted: assert ≤ 10); QWERTY `e` alternates == `["3","ę","é","è","ê","ë","ė"]`, hint `"3"`; Colemak top row has 9 keys and `y` alternates start with `"9"`; `a` (any layout) alternates start with `"ą"`; bottom row kinds == `[.pageNumbers, .language, .emoji, .space, .character("."), .returnKey]` on letters page.
- [ ] Step 2: implement `Layout.swift` (data tables + `rows`).
- [ ] Step 3: commit.

### Task 2: KlawaCore — keyboard state and text operations

**Files:**
- Create: `Core/Sources/KlawaCore/KeyboardState.swift`, `Core/Sources/KlawaCore/TextOps.swift`, `Core/Sources/KlawaCore/PopupGeometry.swift`
- Test: `Core/Tests/KlawaCoreTests/StateTests.swift`, `Core/Tests/KlawaCoreTests/TextOpsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ShiftState { case off, on, capsLock }
  public enum LanguageMode: String, CaseIterable { case auto, pl, en; public var next: LanguageMode }
  public struct KeyboardState {
      public var page: Page; public var shift: ShiftState
      public mutating func tapShift(at time: TimeInterval)       // off→on, on→off; second tap ≤ 0.35 s after a tap that turned it on → capsLock; capsLock→off
      public mutating func typedCharacter()                     // on→off; capsLock stays
      public mutating func typedSpaceOrReturn()                  // numbers/symbols page → letters
  }
  public enum TextOps {
      public static func shouldInsertPeriod(contextBefore: String?, lastSpaceAt: TimeInterval?, now: TimeInterval) -> Bool   // window 0.6 s; before must end with "<letter or digit> "
      public static func wordDeleteCount(contextBefore: String?) -> Int    // Characters to delete: trailing whitespace + previous word; punctuation run counts as a word; ≥ 1 when context non-empty
      public static func cursorOffset(step: Int, contextBefore: String?, contextAfter: String?) -> Int  // UTF-16 offset for moving `step` Characters (neg = left), clamped to available text
  }
  public enum PopupGeometry { public static func originX(keyMidX: Double, popupWidth: Double, containerWidth: Double, margin: Double = 2) -> Double }
  ```

- [ ] Step 1: tests — shift: tap,tap(0.2 s) → `.capsLock`; tap,tap(1 s) → `.off`; `.on` + `typedCharacter` → `.off`; `.capsLock` + `typedCharacter` → `.capsLock`. Period: `("hello ", last 0.3 s ago)` → true; `("hello? ", …)` → false; `(" ", …)` → false; `("hello ", 1.0 s ago)` → false. Word delete: `"ala ma kota  "` → 6; `"to 😀"` → 1; `"wow!!!"` → 3; `""` → 0. Cursor: `step -1` with before `"a😀"` → -2; `step 1` with after `"ę"` → 1; `step -5` with before `"ab"` → -2. Popup: `originX(keyMidX: 5, popupWidth: 100, containerWidth: 390)` → 2; right edge `keyMidX: 388` → 288.
- [ ] Step 2: implement.
- [ ] Step 3: commit.

### Task 3: Emoji catalog

**Files:**
- Create: `scripts/gen-emoji.py` (downloads `https://unicode.org/Public/emoji/16.0/emoji-test.txt`, keeps `fully-qualified` lines, drops group `Component` and skin-tone variants U+1F3FB–1F3FF, writes `Keyboard/emoji.txt`: one line per group `GroupName\t😀 😃 …`)
- Create: `Keyboard/emoji.txt` (generated, committed)
- Create: `Core/Sources/KlawaCore/Emoji.swift`
- Test: `Core/Tests/KlawaCoreTests/EmojiTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct EmojiGroup: Equatable { public let name: String; public let emojis: [String] }
  public enum EmojiCatalog {
      public static func parse(_ text: String) -> [EmojiGroup]
      public static func addRecent(_ emoji: String, to recents: [String], limit: Int = 32) -> [String]   // front, dedupe, cap
  }
  ```
- Group symbols for the category bar (Claude's call): Smileys 😀, People 👋, Animals 🐻, Food 🍔, Travel 🚗, Activities ⚽, Objects 💡, Symbols ❤️, Flags 🏳️; recents 🕘.

- [ ] Step 1: tests — parse of a 2-line sample gives 2 groups with right counts; `addRecent("😀", to: ["😂","😀"])` → `["😀","😂"]`; limit respected.
- [ ] Step 2: implement, run script, check `emoji.txt` has 9 groups and > 1300 emoji.
- [ ] Step 3: commit.

### Task 4: Keyboard UI

**Files:**
- Delete content of: `Keyboard/KeyboardViewController.swift` (rewrite)
- Create: `Keyboard/KeyboardView.swift` (layout + touches + popups), `Keyboard/KeyStyle.swift` (colors/fonts), `Keyboard/EmojiPanel.swift`
- Modify: `project.yml` (package `KlawaCore` → both targets; `Keyboard/emoji.txt` as resource), `.github/workflows/build.yml` (step `swift test --package-path Core` before build)

**Interfaces:**
- Consumes: everything from Tasks 1–3; `AppGroup.defaults`.
- `KeyboardView` exposes callbacks to the controller: `onInsert(String)`, `onDelete(count: Int)`, `onKey(KeyKind)`, `onCursorMove(steps: Int)`; controller owns `textDocumentProxy` calls and `KeyboardState`.

Behavior (values pinned):
- Key height 46 pt, row gap 11 pt, key gap 6 pt, side margin 3 pt, corner radius 8.5, label font 25 pt light (letters), 16 pt (function keys). Short rows centered.
- Colors — light: letter key `#FFFFFF`, function key `#ABB0BA`, shadow `0 1 0 rgba(0,0,0,0.3)`; dark: letter `#6B6B6B`, function `#464646`, no shadow. Background: transparent over the system `UIInputView`.
- Touch-down on a character key: show enlarged key bubble above it; insert on touch-up of that finger. Touch slides to a different key before lifting → that key. Gaps resolve to the nearest key.
- Hold ≥ 0.35 s on a key with alternates → popup strip of alternates (first preselected), slide to choose, lift inserts. Shift on → alternates uppercased (digits unchanged). Digit `hint` drawn small at the key's top-right.
- Backspace: delete 1 on touch-down; after 0.45 s hold repeat every 0.08 s; after 1.6 s of holding delete `wordDeleteCount` per tick every 0.25 s.
- Space: hold 0.3 s (or move > 12 pt horizontally) enters cursor mode: each 9 pt of horizontal movement = 1 step via `cursorOffset` → `adjustTextPosition`. Letter labels fade while in cursor mode. Short tap = space + `shouldInsertPeriod` check.
- Shift key icon: `shift` / `shift.fill` / `capslock.fill` (SF Symbols). Backspace `delete.left`. Emoji `face.smiling`. Return: label from `returnKeyType` (`go`, `search`, `send`, `done`, `next`, `join`, `route`) else `return.left` symbol.
- Field-aware: `.emailAddress` → `.` key becomes `@` and adds `.` (space narrows by 1.0); `.URL` → `.` key becomes `/` with `.com` as alternate; number pad types → start on numbers page.
- Feedback: `UIImpactFeedbackGenerator(.light)` on touch-down when `haptics` and `hasFullAccess`; `UIDevice.current.playInputClick()` (input view adopts `UIInputViewAudioFeedback`).
- Globe: when `needsInputModeSwitchKey` is true, add a globe key left of `lang` (width 1.1, space shrinks). On Face ID iPhones it is normally false.
- Emoji key → `EmojiPanel` replaces the keys (same height): vertical grid 8 per row, recents first, category bar at the bottom with `ABC` (back), group symbols, backspace. Tap inserts + `addRecent` saved under `emojiRecents`.

- [ ] Step 1: wire package + resource + CI test step; push; CI green on `swift test` and build.
- [ ] Step 2: `KeyStyle` + `KeyboardView` layout and character input; controller rewrite.
- [ ] Step 3: popups, long-press alternates, hints.
- [ ] Step 4: shift/caps, pages, backspace repeat, space cursor mode, double-space period, field-aware keys, feedback, language key.
- [ ] Step 5: emoji panel.
- [ ] Step 6: push; CI green; ipa published.

### Task 5: Settings in the app

**Files:**
- Modify: `App/KlawaApp.swift`

- [ ] Step 1: replace "Test etapu 0" with: Settings section (Picker `Layout`: QWERTY / Colemak / Colemak-DH; Toggle `Haptics`) writing to `AppGroup.defaults`; keep setup steps; small "Status" row (group ok/BRAK). Keyboard reads settings in `viewWillAppear`.
- [ ] Step 2: push; CI green.

### Task 6: Phone checklist

**Files:**
- Modify: `docs/INSTALL.md` (add "Test etapu 1" checklist)

- [ ] Step 1: checklist covering Review Focus 1–5, layouts switch, emoji panel, caps lock, cursor drag, backspace, dictation language with `PL`/`EN` mode (does `primaryLanguage` change Apple dictation?).
- [ ] Step 2: commit + push.
