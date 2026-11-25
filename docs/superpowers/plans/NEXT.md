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

- **Phone test 2026-11-25 late (owner):** bar taps work now, press highlight liked, snippets OK, paste prompt
  fixed by owner (Always Allow). Overall "works pretty good". New requests, in the order being built:
  1. Clipboard/snippets rows only react when tapping the text itself; panel buttons (ABC, backspace...) only on
     the glyph. Cause: keyboard extensions ignore touches on fully transparent pixels → give every touchable
     area an almost-invisible background (`KeyStyle.touchable`). Probably also lost taps in key gaps.
  2. Backspace in emoji/clipboard/snippets panels cannot be held (needs repeat like the key).
  3. Key-press bubble flickers when typing fast, unpleasant → off by default (setting), key darkens instead.
  4. Symbols: `$` as its own key next to `zł` on the numbers page, hold `$` → `¢ € £ ¥`; `_` and `#` on the
     numbers page too.
  5. Colemak: remove `;` from the letters page, top row should look different (9 wider keys).
  6. Space a bit small (fine, but bigger is better).
  7. Look more like Apple's keyboard (iOS 26+ Liquid Glass): colors not liked, Apple letters are smaller,
     Apple keys start a few points further from the screen edge, keyboard size differs. Screenshots of both
     keyboards would let us match exactly.
  8. Emoji in suggestions (yes).
  9. Next-word predictions from the start, not only after learning (yes) → corpus word pairs.
  10. Own words / proper nouns (owner's name starting with E that dictation gets wrong): word list in the app,
      exact capitalization, never autocorrected away, suggested. Apple dictation cannot be changed by us
      (tip: the name in the owner's Contacts card helps Apple dictation).
  11. Translator: do it now (owner: why not, plenty of limit left).
  12. Emoji skin tones: nice to have, low priority.
  - Swipe/glide typing: owner does not use it, dropped.

## Next steps, in order

1. Build items 1–12 above, then owner re-tests in one batch.
2. Phase 4 own dictation: not needed (Apple dictation + PL/EN key works).

## Not possible / dropped

- **Genmoji**: iOS gives third-party keyboards no API to create or insert them. Owner uses Apple's emoji keyboard via the globe.
- Auto language mode, Colemak-DH, auto-capitalization, swipe typing (owner's choices).
