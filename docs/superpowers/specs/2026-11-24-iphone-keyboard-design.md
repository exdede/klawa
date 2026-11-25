# Klawa — custom iPhone keyboard (design)

Date: 2026-11-24 · Status: draft, waiting for owner approval
Working name "Klawa" (owner can rename; nothing depends on it).

## Why

Owner moved from Android (Gboard) to iPhone. Tried third-party iOS keyboards, liked none.
Wants the **look and simplicity of the stock iOS keyboard** plus the **Gboard features it misses**,
and above all: **typing in Polish and English without switching languages with the globe key.**
Personal use only, one device. Not for the App Store.

## Device and environment (fixed)

- iPhone 15 Pro Max, iOS 27.2.1, 256 GB.
- Owner has **only a Linux PC**. No Mac, no Windows.
- **Free Apple ID + SideStore** for signing (owner's choice). App expires every 7 days; SideStore refreshes it on the phone.
- GitHub account `exdede` already logged in via `gh`.

## Goals (in owner's priority order)

1. **Bilingual PL+EN typing with no globe switching.** Suggestions draw from both languages at once,
   weighted by the language detected in the current sentence. **One tap** on a language key cycles
   `Auto → PL → EN → Auto` for when detection is wrong. (Owner rejected per-app/per-chat language and
   the Shortcuts-automation trick — not needed.)
2. **Stock-iOS look and feel:** iOS key shapes, colors, light/dark from system, key pop-up on press,
   iOS-like height. Plain, no themes.
3. **Suggestion bar with 3 words** (owner uses it a lot): word completion, next-word prediction,
   spelling correction. Owner is **worried it will be worse than Apple's** — see Quality below.
4. iOS behaviors owner listed from iOS Settings: predictive text, **show math results**
   (`12*3+4` → `40` in the bar), **check spelling**, **caps lock** (double-tap shift), dictation (see 8).
   Plus the basics: **no auto-capitalization at all** (owner's choice, 2026-11-25; Shift is manual only),
   double-space → `. `, backspace hold-repeat (accelerating),
   **space-bar long-press drags the cursor**, number/symbol pages, field-aware keys
   (email/URL keyboards show `@` `.`, return key label follows the field).
5. **Gboard-style long-press for many characters.** Every key has a long-press popup:
   top letter row → digit first (q→1 … p→0, with small digit hint on the key like Gboard),
   letters → accents (a→ą, c→ć, e→ę, l→ł, n→ń, o→ó, s→ś, z→ż ź, plus common other accents),
   punctuation key → `, ? ! ' " - : ; ( ) @ / …` etc. Mappings are plain data, easy to extend.
6. **Layouts:** QWERTY (default), **Colemak**, **Colemak-DH**, switchable in settings.
7. **Smart clipboard (Gboard-style):** history of copied text, tap to paste, **pin** items,
   unpinned items **auto-delete after 1 hour**, and **chips extracted from text** (links, emails,
   phone numbers) so one part of a copied text can be pasted alone.
8. **Dictation:** better than Apple's for mixed PL/EN, like the Claude app's dictation. Staged (see Phases).
9. **Translator** inside the keyboard (later phase, lowest priority).

## Non-goals (now)

Swipe/glide typing · themes/custom colors · grammar checking (iOS gives only spelling to us) ·
emoji search · per-app or per-chat language · App Store / TestFlight · iPad.

## Anti-goals (failure even if it "works")

- Typing feels laggier or less precise than the stock keyboard.
- Suggestions so bad owner switches back to Apple's keyboard.
- Clipboard stores passwords (must skip password-manager items, see Constraints).
- Anything that phones home with typed text, except the explicit dictation/translate features the
  owner turns on.

## iOS constraints that shape the design

- **No microphone in keyboard extensions** (iOS rule). Own dictation must record in the container app.
- **Keyboard does not know the host app or chat** (host-bundle-ID hack dead since iOS 16).
- **No access to Apple's prediction engine.** We get `UITextChecker` (system spell checker, has
  `pl_PL` and `en_US`, gives ranked completions and guesses) and `UILexicon` (contacts names,
  text replacements). Everything else is ours.
- **Clipboard can't be watched in the background.** Keyboard reads `UIPasteboard.general` when it
  appears / on text changes and compares `changeCount`. Needs **Full Access** (`RequestsOpenAccess`).
  Skip items with `org.nspasteboard.ConcealedType` / `TransientType` types (password managers).
- **Keyboard extension memory limit is small (tens of MB).** Word lists must be compact and
  memory-mapped or loaded lazily; no big models inside the extension.
- **Free Apple ID limits:** max 3 sideloaded apps (SideStore uses 1), 10 App IDs per 7 days.
  This project = 2 App IDs (app + keyboard extension). Don't add more extensions.
- **Build needs macOS/Xcode** → done in GitHub Actions; nothing iOS-specific runs locally.
- Secure text fields always get the system keyboard (iOS rule) — fine.

## Approaches considered

| | Option | Trade-off |
|---|---|---|
| **Picked** | **Own UIKit keyboard** in a `UIInputViewController`, shared pure-Swift core package | Full control of look, latency and memory; more code to write (Claude writes it). |
| Rejected | KeyboardKit library | Faster start, but key features (autocomplete, multilingual) are in its paid Pro tier and it locks the look. |
| Rejected | SwiftUI keyboard views | Nicer code, but more memory and touch-latency risk inside the tight extension limit. |

Build pipeline: only one sensible way given Linux-only — **XcodeGen + GitHub Actions macOS runner**
builds an unsigned `.ipa`; **SideStore** on the phone signs and installs it. Owner's choice: free account.
First SideStore install from Linux with **iloader** (official tool, needs `usbmuxd`).

## Structure

```
project.yml                 XcodeGen spec (generated into .xcodeproj on CI)
App/                        container app (SwiftUI): setup guide (enable keyboard + Full Access),
                            settings (layout, autocorrect on/off, haptics, clipboard retention), later dictation host
Keyboard/                   keyboard extension (UIKit): key grid, popups, gestures, suggestion bar, clipboard panel
Core/ (Swift package KlawaCore, no UIKit)
  Layouts                   QWERTY / Colemak / Colemak-DH + long-press maps, as data
  Language                  per-sentence PL/EN detection (dictionary hits + diacritics)
  Suggest                   candidate ranking: frequency lists + bigrams + user-learned words
  Math                      small expression parser/evaluator (+ - * / ^ % parentheses, comma or dot decimals)
  Clipboard                 history model: dedupe, pin, 1h expiry, max items, entity extraction
Resources/                  compact PL + EN frequency word lists (open-licensed), bigram list
.github/workflows/build.yml CI: test KlawaCore, build unsigned .ipa, upload artifact / release
```

**Data sharing (Claude's call): the keyboard is self-sufficient.** Clipboard history and the learned
user dictionary live in the **keyboard's own container**: the keyboard is their only reader and writer,
so they never depend on an App Group. Only two things need an App Group: settings edited in the
container app, and dictation 3b. If App Groups fail under SideStore free signing, settings move into
the keyboard (gear in the suggestion bar) and dictation 3b is dropped.

**Bottom row (owner's choice):** `123 | lang | emoji | space | . | return`. The `lang` key shows `A` / `PL` / `EN`
and cycles on tap; the space bar shows the active language faintly (like iOS). `.` long-press holds the
punctuation set. Globe and system mic stay below the keyboard (iOS draws them on Face ID iPhones).

## Suggestions and quality (owner's main worry)

Candidates for the 3 slots come from: `UITextChecker` completions/guesses for both languages,
bundled frequency lists (~50k word forms each; Polish needs inflected forms), `UILexicon`, and a
**user dictionary learned on-device** from what the owner types (words + word pairs for next-word).
Ranking weights the detected language. Middle slot = best guess; when the current word is unknown
in both languages and a high-confidence correction exists, it is applied on space and **one backspace
undoes it** (like iOS).

**Word data (Claude's call):** unigram lists from `hermitdave/FrequencyWords` (OpenSubtitles 2018,
CC-BY-SA-4.0, has `pl` and `en`, inflected forms included), trimmed to ~50k per language. Next-word
in v1 comes from **on-device learning only**. Stretch goal inside Phase 2: derive top PL+EN bigrams
from the OPUS OpenSubtitles monolingual text with an offline script; ship them only if the file stays
small (a few MB). Learned data never leaves the phone and is never committed.

Honest expectation, to tell the owner: word completion and spelling ≈ close to Apple from day 1
(same system spell checker underneath). **Next-word prediction will start clearly weaker** than Apple's
and improve as it learns the owner's phrases.

**Go/no-go (Claude's call):** after Phase 2 the owner uses Klawa as the main keyboard for a few days.
No evaluation harness. If suggestions are what makes the owner switch back to Apple's, next step is
the bundled bigrams / ranking work before anything else; if still not good enough, the project stops
there (nothing to salvage beyond the code).

## Dictation

- **3a (free, no work):** on Face ID iPhones the system shows the globe and a **dictation mic below
  any keyboard**, including ours. Verify in Phase 0 that it appears and how it picks PL vs EN.
- **3b (later, decision deferred):** own mic key → jumps once to the container app, which keeps a
  background audio session → transcription by a Whisper-class model that handles mixed PL/EN →
  text inserted by the keyboard. Engine choice (cloud API, cents per use, best quality vs on-device,
  free, slower) is decided with the owner when we get there.

## Phases (each ends with the owner testing on the phone)

0. **Pipeline — hard gate, nothing else is built before it passes.** Repo, XcodeGen, CI producing
   `.ipa`, SideStore installed via iloader, a throwaway minimal keyboard (a few letter keys + backspace,
   Full Access requested, writes one value to the App Group) installed and enabled. Check on the phone:
   it types, Full Access toggle exists, system mic appears below it, App Group value readable by the app,
   SideStore refresh works on iOS 27.
1. **Typing core:** layouts, long-press popups, shift/caps, backspace repeat, space cursor drag,
   number/symbol pages, double-space period, field-aware keys, haptic/click feedback,
   **own emoji panel** behind the emoji key (categories + recently used; owner asked for the key next to `lang`).
2. **Suggestions:** bilingual bar, language key `Auto/PL/EN`, spelling, autocorrect + undo, learning, math results. **Go/no-go.**
3. **Clipboard:** history, pin, 1h expiry, chips. Verify iOS paste-permission behavior with Full Access.
4. **Dictation 3b** (if owner still wants it after using 3a).
5. **Translator** (engine decided then).

## Testing

KlawaCore has unit tests (layouts complete, language detection, ranking, math parser, clipboard
expiry/pin/extraction), run by `swift test` on the CI macOS runner on every push. UI is tested by the
owner on the device with a short checklist per phase. Claude cannot run a simulator or see the phone.

## Open / left to the builder

- **Repo: public** (owner's answer) — unlimited free CI minutes; `.ipa` downloadable without login.
- File format for the word lists (memory-mapped sorted text or binary).
- Exact long-press maps beyond the ones above, key sizes and spacing to match iOS.
- Whether to install Swift on Linux for faster local core tests (CI already covers it).
- How the `.ipa` reaches the phone (GitHub release download in Safari vs a SideStore source feed).

## Risks

- **SideStore on iOS 27 is not officially confirmed** (only third-party guides). Fallback: install
  directly from Linux with iloader/Impactor over USB, refreshing weekly by cable.
- App Groups under free signing (fallback above).
- iOS may show a paste-permission prompt when the keyboard reads the clipboard.
- Prediction quality below Apple's (go/no-go at Phase 2).
