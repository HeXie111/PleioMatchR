#!/usr/bin/env python3
"""Convert axis labels / legends / annotations to matplotlib mathtext.

Usage:
    python latexify_labels.py --text "beta-hat for 10^-5, R2 = 0.98"
    python latexify_labels.py --file labels.txt --out latex_labels.csv

Rules live in ../references/latex_rules.json. Output wraps plain text in
r"$...$" when math tokens are detected.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import pandas as pd  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

RULES = json.loads(
    (Path(__file__).resolve().parent.parent / "references" / "latex_rules.json").read_text(
        encoding="utf-8"
    )
)


def latexify(text: str) -> tuple[str, bool]:
    """Return (mathtext string, is_math) for a label."""
    original = text
    out = text

    def _expand(m: re.Match, repl: str) -> str:
        # expand numeric backrefs while keeping LaTeX backslashes literal
        return re.sub(r"\\([1-9])", lambda mm: m.group(int(mm.group(1))), repl)

    # compound words first (beta-hat, p-value, ...) so greek substitution
    # below cannot break them
    for en, tex in RULES["words"].items():
        out = out.replace(en, tex).replace(en.capitalize(), tex)
    greek = RULES["greek"]
    for en, sym in sorted(greek.items(), key=lambda kv: -len(kv[0])):
        # skip names that are already part of a LaTeX command (\beta)
        pattern = rf"(?<![A-Za-z\\]){en}(?![A-Za-z])"
        out = re.sub(pattern, lambda m: sym, out, flags=re.I)
    for rule in RULES["patterns"]:
        out = re.sub(rule["regex"], lambda m: _expand(m, rule["replacement"]), out)
    math_used = out != original or bool(re.search(r"[\\^{}_]", out))
    return out, math_used


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--text")
    src.add_argument("--file", type=Path)
    ap.add_argument("--col", default=None, help="CSV column to convert")
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()

    if args.file:
        if args.file.suffix.lower() in (".csv", ".tsv"):
            df = pd.read_csv(args.file, sep=None, engine="python")
            col = args.col or df.columns[0]
            rows = []
            for raw in df[col].astype(str):
                tex, is_math = latexify(raw)
                rows.append({"raw": raw, "latex": tex, "is_math": is_math})
            result = pd.DataFrame(rows)
            dest = args.out or args.file.with_name(args.file.stem + "_latex.csv")
            result.to_csv(dest, index=False)
            print(f"latex labels: {dest}")
            print(result.head(10).to_string(index=False))
        else:
            lines = [ln.rstrip("\n") for ln in args.file.read_text(encoding="utf-8").splitlines() if ln.strip()]
            out_lines = []
            for raw in lines:
                tex, is_math = latexify(raw)
                out_lines.append(f"{raw}\t{tex}\t{is_math}")
            dest = args.out or args.file.with_suffix(".tsv")
            dest.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
            print(f"latex labels: {dest}")
    else:
        tex, is_math = latexify(args.text)
        wrapped = f'r"${tex}$"' if is_math else f'"{tex}"'
        print(f"raw    : {args.text}")
        print(f"latex  : {wrapped}")


if __name__ == "__main__":
    main()
