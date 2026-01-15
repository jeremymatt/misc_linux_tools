#!/usr/bin/env python3
"""
High-entropy passphrase generator.

Defaults:
  - 4 words
  - random separator symbol
  - large wordlist if available

Options:
  --nums                Ensure at least one digit appears
  --rand_caps word      Randomly capitalize entire words
  --rand_caps char      Randomly capitalize individual characters
"""

import argparse
import secrets
import string
import sys
import re
from pathlib import Path
import urllib.request


DEFAULT_SEP_SET = "!@#$%^&*_-+=:.?/"
DEFAULT_WORDLIST_CANDIDATES = [
    "/usr/share/dict/words",
    "/usr/dict/words",
]

EFF_LONG_URL = "https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt"
DEFAULT_EFF_FILENAME = "eff_large_wordlist.txt"


FALLBACK_WORDS = """
orbit slate lantern harbor cactus wagon ethics copper bundle quiet ribbon falcon magnet
summit violet pocket entropy drift cabin ember signal mango stitch river temple velvet
glacier kettle fossil canopy lunar maple marble meadow memory mirror mobile monarch
mosaic mountain nectar nickel normal object orbit oxygen palace parent phoenix picnic
pocket polar portal power prefer pressure problem process quiet radar ribbon robust
rocket romance routine salmon science secret shadow silver simple solar solid summit
symbol system talent temple theory thunder timber travel tunnel velvet vision vivid
wagon walnut window winter wisdom wonder yellow zenith
""".split()


def eprint(*a):
    print(*a, file=sys.stderr)


def valid_word(w, min_len, max_len):
    return min_len <= len(w) <= max_len and re.fullmatch(r"[a-z]+", w)


def load_words(path, min_len, max_len):
    out = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            w = line.strip().lower()
            if valid_word(w, min_len, max_len):
                out.append(w)
    return list(dict.fromkeys(out))


def find_default_wordlist():
    for p in DEFAULT_WORDLIST_CANDIDATES:
        if Path(p).exists():
            return Path(p)
    return None


def download_eff(dest):
    eprint("Downloading EFF wordlist…")
    data = urllib.request.urlopen(EFF_LONG_URL).read()
    dest.write_bytes(data)
    eprint("Done.")


def parse_eff(path, min_len, max_len):
    words = []
    with open(path, "r") as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 2:
                w = parts[1].lower()
                if valid_word(w, min_len, max_len):
                    words.append(w)
    return list(dict.fromkeys(words))


def random_sep(sep, sep_set):
    if sep:
        return sep
    return secrets.choice(list(sep_set))


def apply_word_caps(words):
    n = len(words)

    # Choose how many words to capitalize: 1 .. n
    count = secrets.randbelow(n) + 1

    # Select unique indices securely
    idxs = set()
    while len(idxs) < count:
        idxs.add(secrets.randbelow(n))

    for i in idxs:
        words[i] = words[i].upper()

    return words


def apply_char_caps(s):
    out = []
    for c in s:
        if c.isalpha() and secrets.randbelow(4) == 0:
            out.append(c.upper())
        else:
            out.append(c)
    return "".join(out)


def inject_digit(s):
    pos = secrets.randbelow(len(s) + 1)
    return s[:pos] + secrets.choice(string.digits) + s[pos:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--words", type=int, default=4)
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--sep", default=None)
    ap.add_argument("--sep-set", default=DEFAULT_SEP_SET)
    ap.add_argument("--wordlist", default=None)
    ap.add_argument("--download-eff", action="store_true")
    ap.add_argument("--min-len", type=int, default=4)
    ap.add_argument("--max-len", type=int, default=10)
    ap.add_argument("--nums", action="store_true")
    ap.add_argument("--rand_caps", choices=["word", "char"])

    args = ap.parse_args()

    if args.wordlist:
        words = load_words(args.wordlist, args.min_len, args.max_len)
    elif args.download_eff:
        p = Path(DEFAULT_EFF_FILENAME)
        if not p.exists():
            download_eff(p)
        words = parse_eff(p, args.min_len, args.max_len)
    else:
        p = find_default_wordlist()
        if p:
            words = load_words(p, args.min_len, args.max_len)
        else:
            words = [w for w in FALLBACK_WORDS if valid_word(w, args.min_len, args.max_len)]

    if len(words) < 500:
        eprint(f"Warning: wordlist only {len(words)} words")

    for _ in range(args.count):
        sep = random_sep(args.sep, args.sep_set)
        chosen = [secrets.choice(words) for _ in range(args.words)]

        if args.rand_caps == "word":
            chosen = apply_word_caps(chosen)

        s = sep.join(chosen)

        if args.rand_caps == "char":
            s = apply_char_caps(s)

        if args.nums:
            s = inject_digit(s)

        print(s)


if __name__ == "__main__":
    main()

