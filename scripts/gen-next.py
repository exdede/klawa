#!/usr/bin/env python3
"""Generate Keyboard/next.txt: likely next words, from OpenSubtitles 2018 subtitles (OPUS, mono corpus).

Streams the start of each language's corpus (no full download), counts word pairs separated only by a space,
and keeps the top next words for the most common words. `<s>` = start of a line (sentence).
Output: `p|e<TAB>previous<TAB>next next ...`. Needs Keyboard/words.txt (scripts/gen-words.py) for the vocabulary.

Usage: gen-next.py [lines per language, default 6000000]
"""
import gzip
import re
import sys
import urllib.request
from collections import Counter

URL = "https://object.pouta.csc.fi/OPUS-OpenSubtitles/v2018/mono/{}.txt.gz"
TOKEN = {"pl": re.compile(r"[a-ząćęłńóśźż]+|[^\sa-ząćęłńóśźż]+"),
         "en": re.compile(r"[a-z]+(?:'[a-z]+)?|[^\sa-z']+|'")}
PREV_LIMIT, NEXT_LIMIT, KEEP, MIN_COUNT = 15_000, 40_000, 6, 3


def vocabulary():
    words = {"p": [], "e": []}
    for line in open("Keyboard/words.txt", encoding="utf-8"):
        w, lang, count = line.rstrip("\n").split("\t")
        words[lang].append((int(count), w))
    out = {}
    for lang, items in words.items():
        items.sort(reverse=True)
        cased = {w.lower(): w for _, w in items}  # "i" -> "I"
        ranked = [w.lower() for _, w in items]
        out[lang] = (set(ranked[:PREV_LIMIT]), set(ranked[:NEXT_LIMIT]), cased)
    return out


def count(lang, limit, prev_ok, next_ok):
    ids, names = {}, []
    def wid(w):
        if w not in ids:
            ids[w] = len(names)
            names.append(w)
        return ids[w]
    pairs = Counter()
    start = wid("<s>")
    stream = gzip.open(urllib.request.urlopen(URL.format(lang), timeout=60), "rt", encoding="utf-8", errors="ignore")
    for n, line in enumerate(stream):
        if n >= limit:
            break
        prev = start
        for tok in TOKEN[lang].findall(line.lower()):
            if tok in next_ok:
                if prev is not None:
                    pairs[prev * 1_000_000 + wid(tok)] += 1
                prev = wid(tok) if tok in prev_ok else None
            elif tok in ("-", "—", "\"", "„", "”"):
                continue  # dialogue dash or quote at line start: still the sentence start
            else:
                prev = start if tok in (".", "!", "?", "...", "…") else None
        if len(pairs) > 8_000_000:  # keep memory bounded: drop pairs seen once
            pairs = Counter({k: v for k, v in pairs.items() if v > 1})
    table = {}
    for key, c in pairs.items():
        if c >= MIN_COUNT:
            table.setdefault(key // 1_000_000, []).append((c, names[key % 1_000_000]))
    return {names[p]: [w for _, w in sorted(v, reverse=True)[:KEEP]] for p, v in table.items()}


def main():
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 6_000_000
    vocab = vocabulary()
    with open("Keyboard/next.txt", "w", encoding="utf-8") as f:
        for lang, code in (("pl", "p"), ("en", "e")):
            prev_ok, next_ok, cased = vocab[code]
            table = count(lang, limit, prev_ok, next_ok)
            for prev in sorted(table):
                f.write(f"{code}\t{prev}\t{' '.join(cased.get(w, w) for w in table[prev])}\n")
            print(lang, len(table), "words with next words")


if __name__ == "__main__":
    main()
