#!/usr/bin/env python3
"""
passphrase_gen.py

Generates high-entropy passphrases from a large wordlist.

Defaults:
  - 4 words
  - separator is a randomly selected symbol (per passphrase)
  - uses a large system wordlist if available (e.g., /usr/share/dict/words)

Examples:
  ./passphrase_gen.py
  ./passphrase_gen.py --words 6
  ./passphrase_gen.py --count 10
  ./passphrase_gen.py --sep "-"              # fixed separator
  ./passphrase_gen.py --sep-set "_-.:+@"     # choose randomly from these
  ./passphrase_gen.py --wordlist ./words.txt
  ./passphrase_gen.py --download-eff         # downloads EFF long wordlist (7776 words)
"""

from __future__ import annotations

import argparse
import os
import re
import secrets
import sys
import urllib.request
from pathlib import Path
from typing import Iterable, List, Optional


DEFAULT_SEP_SET = "!@#$%^&*_-+=:.?/"
DEFAULT_WORDLIST_CANDIDATES = [
    "/usr/share/dict/words",
    "/usr/dict/words",
]


# Small fallback list if no large wordlist is found and user doesn't provide one.
# The intent is that most systems will use /usr/share/dict/words (or user-supplied list).
FALLBACK_WORDS = """
abacus abandon ability abrupt academy acorn across action active adapt admire
advice airport almond anchor ancient angle animal ankle answer anthem anyone
apricot arcade arctic artist atom audit autumn avenue bacon badge balance banner
barrel basic battery beacon beauty begin belong bicycle bitter blanket blossom
border borrow bracket breeze bronze cabin cactus camera canyon captain carbon
carpet castle causal cedar celery cement chance chapter cherry circle civic
climate coast coffee comet common concert copper coral cotton council cousin
cradle craft credit creek crimson crisp critic cosmic custom dance decade decide
demand desert design detail device dinner direct district dragon drift during
eager earthly echo eclipse editor effect effort eight either elbow elder elect
ember emerge emotion employ enable engine enough enjoy enrich escape estate ethics
evening exact exile exist expand expert expose fabric falcon family famous fancy
federal ferry fever fiction filter final finish fiscal flame forest fossil frame
frequent friendly galaxy garden garment gentle glacier golden gravity habitat
harbor hazard hero hidden honest horizon humble hybrid idea ignore image impact
income index indoor infant inform inherit island jewel jungle kettle ladder
lantern laptop legacy lemon liberty linen lion logic lunar magnet maple marble
market meadow memory merit mimic mineral mirror mobile moment monarch monitor
mosaic mountain museum nation nectar neutral nickel normal notice object orbit
origin output oxygen palace panel parent patient percent phoenix picnic pioneer
pocket polar portal postage power prefer pressure problem process profit public
quiet radar radius random raven ready reason record reform report rhythm ribbon
river robust rocket romance routine rural salad salmon satellite science secret
senior shadow signal silver simple sister slate solar solid summit symbol system
talent temple theory thunder timber token topic travel treaty tunnel uniform
update useful vacuum velvet vendor verdict vessel veteran violet vision vivid
wagon walnut window winter wisdom wonder woven yellow zenith
""".split()


EFF_LONG_URL = "https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt"
DEFAULT_EFF_FILENAME = "eff_large_wordlist.txt"


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def is_reasonable_word(word: str, *, min_len: int, max_len: int, allow_apostrophe: bool) -> bool:
    w = word.strip()
    if not w:
        return False
    if len(w) < min_len or len(w) > max_len:
        return False

    # Filter out proper nouns / acronyms and non-words from system dictionaries.
    # We keep: lowercase letters (optionally apostrophe).
    if allow_apostrophe:
        return bool(re.fullmatch(r"[a-z]+(?:'[a-z]+)?", w))
    return bool(re.fullmatch(r"[a-z]+", w))


def load_words_from_file(path: Path, *, min_len: int, max_len: int, allow_apostrophe: bool) -> List[str]:
    words: List[str] = []
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            w = line.strip().lower()
            if is_reasonable_word(w, min_len=min_len, max_len=max_len, allow_apostrophe=allow_apostrophe):
                words.append(w)
    # Deduplicate while preserving order
    seen = set()
    uniq: List[str] = []
    for w in words:
        if w not in seen:
            uniq.append(w)
            seen.add(w)
    return uniq


def find_default_wordlist() -> Optional[Path]:
    for p in DEFAULT_WORDLIST_CANDIDATES:
        path = Path(p)
        if path.exists() and path.is_file():
            return path
    return None


def download_eff_wordlist(dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    eprint(f"Downloading EFF wordlist to: {dest}")
    with urllib.request.urlopen(EFF_LONG_URL, timeout=30) as resp:
        content = resp.read()
    dest.write_bytes(content)
    eprint("Download complete.")


def parse_eff_wordlist(path: Path, *, min_len: int, max_len: int, allow_apostrophe: bool) -> List[str]:
    """
    EFF file format: "<dice> <word>" per line, e.g. "11111 abacus"
    """
    words: List[str] = []
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            w = parts[1].strip().lower()
            if is_reasonable_word(w, min_len=min_len, max_len=max_len, allow_apostrophe=allow_apostrophe):
                words.append(w)
    # EFF list already unique, but dedupe anyway
    return list(dict.fromkeys(words))


def choose_separator(sep: Optional[str], sep_set: str) -> str:
    if sep is not None:
        return sep
    if not sep_set:
        # If user empties sep-set, fall back to a hyphen.
        return "-"
    return secrets.choice(list(sep_set))


def generate_passphrase(
    words: List[str],
    *,
    n_words: int,
    separator: str,
    titlecase: bool,
) -> str:
    chosen = [secrets.choice(words) for _ in range(n_words)]
    if titlecase:
        # Randomly title-case exactly one word for slight entropy and readability
        idx = secrets.randbelow(len(chosen))
        chosen[idx] = chosen[idx].capitalize()
    return separator.join(chosen)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate passphrases from a large wordlist.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    ap.add_argument("--words", type=int, default=4, help="Number of words per passphrase.")
    ap.add_argument("--count", type=int, default=1, help="Number of passphrases to output.")
    ap.add_argument("--sep", default=None, help="Fixed separator string. If omitted, choose randomly from --sep-set.")
    ap.add_argument(
        "--sep-set",
        default=DEFAULT_SEP_SET,
        help="Set of separator characters to choose from when --sep is not provided.",
    )
    ap.add_argument(
        "--wordlist",
        default=None,
        help="Path to a wordlist file (one word per line). If omitted, tries common system dictionaries.",
    )
    ap.add_argument(
        "--download-eff",
        action="store_true",
        help=f"Download the EFF large wordlist ({DEFAULT_EFF_FILENAME}) into the current directory and use it.",
    )
    ap.add_argument("--min-len", type=int, default=4, help="Minimum word length to include.")
    ap.add_argument("--max-len", type=int, default=10, help="Maximum word length to include.")
    ap.add_argument(
        "--allow-apostrophe",
        action="store_true",
        help="Allow words containing a single apostrophe (e.g., don't).",
    )
    ap.add_argument(
        "--titlecase",
        action="store_true",
        help="Randomly TitleCase one word in each passphrase.",
    )

    args = ap.parse_args()

    if args.words < 2:
        eprint("Error: --words must be >= 2 for a sensible passphrase.")
        return 2
    if args.count < 1:
        eprint("Error: --count must be >= 1.")
        return 2
    if args.min_len < 1 or args.max_len < args.min_len:
        eprint("Error: invalid --min-len/--max-len.")
        return 2

    # Determine wordlist source
    words: List[str] = []

    if args.download_eff:
        eff_path = Path.cwd() / DEFAULT_EFF_FILENAME
        if not eff_path.exists():
            download_eff_wordlist(eff_path)
        words = parse_eff_wordlist(
            eff_path,
            min_len=args.min_len,
            max_len=args.max_len,
            allow_apostrophe=args.allow_apostrophe,
        )
    else:
        wl_path: Optional[Path] = None
        if args.wordlist:
            wl_path = Path(args.wordlist)
            if not wl_path.exists() or not wl_path.is_file():
                eprint(f"Error: wordlist file not found: {wl_path}")
                return 2
            words = load_words_from_file(
                wl_path,
                min_len=args.min_len,
                max_len=args.max_len,
                allow_apostrophe=args.allow_apostrophe,
            )
        else:
            default_path = find_default_wordlist()
            if default_path is not None:
                words = load_words_from_file(
                    default_path,
                    min_len=args.min_len,
                    max_len=args.max_len,
                    allow_apostrophe=args.allow_apostrophe,
                )
            else:
                words = [w for w in FALLBACK_WORDS if is_reasonable_word(
                    w, min_len=args.min_len, max_len=args.max_len, allow_apostrophe=args.allow_apostrophe
                )]

    if len(words) < 1000:
        eprint(
            f"Warning: wordlist size is only {len(words)} words after filtering. "
            "For best results, use --download-eff or provide a large custom --wordlist."
        )
    if len(words) == 0:
        eprint("Error: no usable words available after filtering.")
        return 2

    # Generate
    for _ in range(args.count):
        sep = choose_separator(args.sep, args.sep_set)
        print(
            generate_passphrase(
                words,
                n_words=args.words,
                separator=sep,
                titlecase=args.titlecase,
            )
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

