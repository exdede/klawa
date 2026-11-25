#!/usr/bin/env python3
"""Generate Keyboard/words.txt from FrequencyWords (OpenSubtitles 2018, CC-BY-SA-4.0).

Output: `word<TAB>p|e<TAB>count`, sorted by the folded form (see Lexicon.fold in KlawaCore:
lowercase, Polish letters to base letters, apostrophes removed), so the keyboard can binary-search it.

Usage: gen-words.py [dir with pl_full.txt and en_full.txt] (downloads them when no dir is given)
"""
import re
import sys
import urllib.request
from pathlib import Path

URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/{0}/{0}_full.txt"
LIMITS = {"pl": 120_000, "en": 60_000}
LETTERS = {"pl": re.compile(r"[a-ząćęłńóśźż]+"), "en": re.compile(r"[a-z]+")}
SINGLE = {"pl": set("aiouwz"), "en": set("ai")}
FOLD = str.maketrans("ąćęłńóśźż", "acelnoszz", "'")
# OpenSubtitles splits "don't" into "don" + "'t"; rebuild the common ones.
STEM_ONLY = "don doesn didn isn wasn aren weren couldn wouldn shouldn haven hasn hadn ain".split()
CONTRACTIONS = ("I'm it's that's you're we're they're I'll you'll we'll they'll I've you've we've they've I'd you'd "
                "he's she's what's there's here's who's where's let's can't won't").split()


def fold(w):
    return w.lower().translate(FOLD)


def load(lang, src):
    if src:
        text = (Path(src) / f"{lang}_full.txt").read_text(encoding="utf-8")
    else:
        text = urllib.request.urlopen(URL.format(lang), timeout=60).read().decode("utf-8")
    counts = {}
    for line in text.splitlines():
        word, _, count = line.rpartition(" ")
        counts[word] = counts.get(word, 0) + int(count)
    return counts


def words_for(lang, counts):
    out = {w: c for w, c in counts.items()
           if LETTERS[lang].fullmatch(w) and (len(w) > 1 or w in SINGLE[lang])}
    if lang == "en":
        for stem in STEM_ONLY:
            if stem in out:
                out[stem + "'t"] = out.pop(stem)
        for c in CONTRACTIONS:
            stem, suffix = c.lower().split("'")
            out[c] = min(counts.get(stem, 0), counts.get("'" + suffix, 0)) // 2
        out["I"] = out.pop("i")
    total = sum(counts.values())
    return {w: c / total for w, c in out.items() if c > 0}, out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    rel, raw = {}, {}
    for lang in LIMITS:
        rel[lang], raw[lang] = words_for(lang, load(lang, src))
    # Subtitles often skip Polish letters ("zrobie", English list even has "sie"); drop a form far
    # rarer than another word with the same folded spelling in either language, so typing it gets corrected.
    best = {}
    for lang in LIMITS:
        for w, r in rel[lang].items():
            best[fold(w)] = max(best.get(fold(w), 0), r)
    rows = []
    for lang in LIMITS:
        kept = [(w, r) for w, r in rel[lang].items() if r * 10 >= best[fold(w)]]
        kept.sort(key=lambda wr: -wr[1])
        rows += [(w, lang[0], raw[lang][w]) for w, _ in kept[:LIMITS[lang]]]
    rows.sort(key=lambda r: (fold(r[0]), r[1], r[0]))
    with open("Keyboard/words.txt", "w", encoding="utf-8") as f:
        for w, l, c in rows:
            f.write(f"{w}\t{l}\t{c}\n")
    print(len(rows), "words")


if __name__ == "__main__":
    main()
