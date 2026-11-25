# Klawa — status and next version

Updated: 2026-11-25. Read with the spec: `docs/superpowers/specs/2026-11-24-iphone-keyboard-design.md`.

## Where we are

- **Phase 0 done** (verified on the phone): CI builds `.ipa`, owner installs with **iloader → Import IPA** over USB
  (SideStore dropped, Apple ID login on the phone failed). App Group works (ID read from embedded.mobileprovision).
- **Phase 1 built** (`docs/superpowers/plans/2026-11-25-phase1-typing.md`), first phone test 2026-11-25:
  - works: typing, emoji panel, `zł`, layouts, language key sets **Apple dictation language** (PL/EN).
  - owner feedback, fixed in commit `fix: lost spaces and taps…` (**not yet re-tested on the phone**):
    lost spaces (cursor mode too eager), lost letters (top bar swallowed touches, cancelled touches, roll-off),
    long-press must give the Polish letter on plain release (`o` → ó), Auto language mode dropped (PL ↔ EN only),
    Colemak top row looked odd (`;` restored), Colemak-DH removed.

- **Phase 2 + emoji search + Phase 3 built 2026-11-25** (owner said: build the rest, ask for tests only when needed;
  **not yet tested on the phone**, checklist `docs/INSTALL.md` "Test etapu 2 i 3"):
  - word list `Keyboard/words.txt` (scripts/gen-words.py, FrequencyWords OpenSubtitles 2018, CC-BY-SA-4.0):
    120k PL + 60k EN, diacritic-less subtitle forms dropped so `zrobie` → `zrobię`.
  - `KlawaCore`: Lexicon (folded binary search), Suggester (completions, Polish-letter fixes, one-typo fixes
    with neighbor-key costs, learned words, next word from learned pairs), MathEval, TouchModel, EmojiSearch,
    ClipboardHistory + ClipExtract.
  - keyboard: SuggestionBar (3 slots, autocorrect slot highlighted, clipboard icon), autocorrect on space/return/
    punctuation with backspace undo, learning in UserDefaults of the extension, invisible key resizing
    (Gaussian touch + capped letter odds), emoji search in the bar, ClipboardPanel (pin, delete, 1h expiry,
    password-manager items skipped).

- **Phone test 2026-11-25 evening (owner):** "overall works pretty good". Full Access on. iOS asked to allow
  pasting (keyboard reads the pasteboard on each new copy; Settings → Klawa → Paste from Other Apps → Allow
  should stop it, unconfirmed). Suggestion bar taps often did nothing → bar now handles slot touches itself
  (whole third of the bar, press highlight). Not yet re-tested.
- **Snippets (owner asked 2026-11-25):** categories of saved texts (emails, sites, misc), edited in the Klawa
  app (`SnippetsView`), inserted from the keyboard (speech-bubble icon next to the clipboard icon).
  Stored as JSON in App Group defaults (`Shared/Snippets.swift`). Not yet tested.

## Next steps, in order

1. **Owner re-tests**: bar taps, snippets, paste prompt. Unknowns still to watch: lexicon memory/load time,
   autocorrect strength, touch bias strength (`TouchModel.weight`/`maxLogRatio`).
2. **Owner's call on what next** (translator is lower priority than snippets, owner said). Candidates:
   - Phase 5 translator: Apple Translation framework (iOS 26+ `TranslationSession` without SwiftUI) if usable
     in a keyboard extension.
   - Swipe (glide) typing like Gboard: big piece of work, would reuse the lexicon.
   - Emoji in suggestions for words (`pizza` → 🍕), from the emoji keyword data.
   - Better next-word predictions from corpus word pairs (now only learned pairs, bar is empty until learned).
   - Save a clipboard item straight into a snippet category.
   - Skin-tone picker for emoji.
3. Phase 4 own dictation: not needed (Apple dictation + PL/EN key works).

## Not possible / dropped

- **Genmoji**: iOS gives third-party keyboards no API to create or insert them. Owner uses Apple's emoji keyboard via the globe.
- Auto language mode, Colemak-DH, auto-capitalization (owner's choices).
