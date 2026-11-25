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

## Next steps, in order

1. **Re-test Phase 1 fixes on the phone** (checklist: `docs/INSTALL.md`, section "Test etapu 1").
   If letters are still lost during fast two-thumb typing, investigate `KeyboardView` touch handling
   (touch delays near screen edges, commit order in `commitPendingCharacters`).
2. **Next version — pick order with the owner:**
   - **Phase 2: suggestion bar** (3 words, PL+EN, favors the language key, spelling, autocorrect with undo,
     learning, math results). Main go/no-go point of the project (see spec).
   - **Emoji search** (owner asked 2026-11-25): search field at the top of the emoji panel, typed with Klawa's
     own keys (keystrokes go to the search field, not the host app). Keywords: English names from
     `emoji-test.txt` + Polish and English keywords from Unicode CLDR annotations (`pl.xml`, `en.xml`),
     generated offline by extending `scripts/gen-emoji.py` into a compact resource. Results row = tap to insert.
3. Phase 3 clipboard, Phase 4 own dictation (maybe not needed: Apple dictation + PL/EN key works), Phase 5 translator.

## Not possible / dropped

- **Genmoji**: iOS gives third-party keyboards no API to create or insert them. Owner uses Apple's emoji keyboard via the globe.
- Auto language mode, Colemak-DH, auto-capitalization (owner's choices).
