#!/usr/bin/env python3
"""Generate Keyboard/emoji.txt from Unicode emoji-test.txt and Keyboard/emoji-keywords.txt
from Unicode CLDR annotations (Polish + English names and keywords, for emoji search).

emoji.txt: one line per group, `Name<TAB>emoji emoji ...`. Fully-qualified emoji only,
no Component group, no skin-tone variants.
emoji-keywords.txt: `emoji<TAB>keyword|keyword...`, folded like Lexicon.fold, catalog order.
shortcut: no skin-tone picker, add one if the owner wants it.
"""
import sys
import urllib.request
import xml.etree.ElementTree as ET

URL = "https://unicode.org/Public/emoji/16.0/emoji-test.txt"  # iOS 18.4+ renders all of 16.0
SKIN_TONES = {chr(c) for c in range(0x1F3FB, 0x1F400)}
CLDR = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/{}/{}.xml"
FOLD = str.maketrans("ąćęłńóśźż", "acelnoszz", "'’")


def keywords():
    """emoji without FE0F -> folded keywords and names from pl and en."""
    out = {}
    for lang in ("pl", "en"):
        for kind in ("annotations", "annotationsDerived"):
            root = ET.fromstring(urllib.request.urlopen(CLDR.format(kind, lang), timeout=30).read())
            for a in root.iter("annotation"):
                words = [w.strip().lower().translate(FOLD) for w in (a.text or "").split("|")]
                kws = out.setdefault(a.get("cp").replace("\ufe0f", ""), [])
                for w in words:
                    if w and w not in kws:
                        kws.append(w)
    return out


GROUPS = {
    "Smileys & Emotion": "Smileys",
    "People & Body": "People",
    "Animals & Nature": "Animals",
    "Food & Drink": "Food",
    "Travel & Places": "Travel",
    "Activities": "Activities",
    "Objects": "Objects",
    "Symbols": "Symbols",
    "Flags": "Flags",
}


def main(out_path):
    text = urllib.request.urlopen(URL, timeout=30).read().decode("utf-8")
    groups, current = {}, None
    for line in text.splitlines():
        if line.startswith("# group:"):
            current = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#") or current not in GROUPS:
            continue
        codes, rest = line.split(";", 1)
        if not rest.strip().startswith("fully-qualified"):
            continue
        emoji = "".join(chr(int(c, 16)) for c in codes.split())
        if SKIN_TONES & set(emoji):
            continue
        groups.setdefault(GROUPS[current], []).append(emoji)
    assert len(groups) == len(GROUPS), groups.keys()
    with open(out_path, "w", encoding="utf-8") as f:
        for name in GROUPS.values():
            f.write(f"{name}\t{' '.join(groups[name])}\n")
    print({k: len(v) for k, v in groups.items()}, sum(map(len, groups.values())))
    kw = keywords()
    found = 0
    with open(out_path.replace("emoji.txt", "emoji-keywords.txt"), "w", encoding="utf-8") as f:
        for name in GROUPS.values():
            for e in groups[name]:
                words = kw.get(e.replace("\ufe0f", ""))
                if words:
                    found += 1
                    f.write(f"{e}\t{'|'.join(words)}\n")
    print(found, "emoji with keywords")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Keyboard/emoji.txt")
