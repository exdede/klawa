#!/usr/bin/env python3
"""Generate Keyboard/emoji.txt from Unicode emoji-test.txt.

Output: one line per group, `Name<TAB>emoji emoji ...`. Fully-qualified emoji only,
no Component group, no skin-tone variants.
shortcut: no skin-tone picker, add one if the owner wants it.
"""
import sys
import urllib.request

URL = "https://unicode.org/Public/emoji/16.0/emoji-test.txt"  # iOS 18.4+ renders all of 16.0
SKIN_TONES = {chr(c) for c in range(0x1F3FB, 0x1F400)}
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


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "Keyboard/emoji.txt")
