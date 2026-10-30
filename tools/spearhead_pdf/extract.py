"""Extracts the text of a Spearhead rules PDF from Warhammer Community, one page at a time.

Usage: python -I extract.py <pdf> [<pdf> ...] [--mode layout|plain|both] [--out <dir>]

Prints each page's text under a "=== <file> page <n> (<mode>) ===" line, or with --out writes
<dir>/<pdf name>.txt. Layout mode keeps the page's columns, so ability text reads in order, but
pypdf leaves out rotated text, which includes the warscrolls' weapon tables. Plain mode has the
weapon tables and stat values, in a jumbled order. The default, both, gives each page in layout
mode then plain mode. Needs pypdf (in the "aos" pyenv virtualenv; see requirements.txt).
"""

import argparse
import logging
import os
import sys

from pypdf import PdfReader

MODES = ("layout", "plain")


def pages(path, mode):
    """The text of each page of the PDF at [path], in pypdf's [mode] ("layout" or "plain")."""
    reader = PdfReader(path)
    return [page.extract_text(extraction_mode=mode) or "" for page in reader.pages]


def as_text(path, modes=MODES):
    name = os.path.basename(path)
    by_mode = {mode: pages(path, mode) for mode in modes}
    count = len(next(iter(by_mode.values())))
    return "\n".join("=== %s page %d (%s) ===\n%s" % (name, i + 1, mode, by_mode[mode][i])
                     for i in range(count) for mode in modes)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pdfs", nargs="+")
    parser.add_argument("--mode", choices=MODES + ("both",), default="both")
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    # pypdf warns on every page with rotated text; the docstring says what layout mode leaves out.
    logging.getLogger("pypdf").setLevel(logging.ERROR)
    modes = MODES if args.mode == "both" else (args.mode,)
    for path in args.pdfs:
        text = as_text(path, modes)
        if args.out:
            os.makedirs(args.out, exist_ok=True)
            out = os.path.join(args.out, os.path.splitext(os.path.basename(path))[0] + ".txt")
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(text + "\n")
        else:
            print(text)


if __name__ == "__main__":
    main(sys.argv[1:])
