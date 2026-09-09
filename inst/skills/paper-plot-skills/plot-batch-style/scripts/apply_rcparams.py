#!/usr/bin/env python3
"""Inject a global matplotlib rcParams template into many figure scripts.

Examples:
    python apply_rcparams.py --rcparams ../stylebank/rcparams_nature.json \
        --files a.py b.py --out-dir unified/
    python apply_rcparams.py --rcparams my.json --files a.py --inplace
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared"))
from plot_utils import py_dumps  # noqa: E402


def parse_rcparams(value: str) -> dict:
    path = Path(value)
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    # built-in journal names map to the bundled stylebank templates
    aliases = {
        "nature": "rcparams_nature.json",
        "cell": "rcparams_cell.json",
        "plos": "rcparams_plos.json",
        "plos_one": "rcparams_plos.json",
        "lancet": "rcparams_lancet.json",
    }
    if value in aliases:
        path = Path(__file__).resolve().parent.parent / "stylebank" / aliases[value]
        return json.loads(path.read_text(encoding="utf-8"))
    raise ValueError(f"cannot resolve rcParams template: {value}")


def find_update_block(text: str, start: int) -> tuple[int, int] | None:
    """Locate the balanced `plt.rcParams.update({ ... })` block."""
    idx = text.find("plt.rcParams.update(", start)
    if idx < 0:
        return None
    brace_start = text.find("{", idx + len("plt.rcParams.update("))
    if brace_start < 0:
        return None
    depth = 0
    for i in range(brace_start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                # skip whitespace and consume the closing parenthesis
                j = i + 1
                while j < len(text) and text[j] in " \t\r\n":
                    j += 1
                if j < len(text) and text[j] == ")":
                    j += 1
                return idx, j
    return None


def inject_rcparams(source: str, rcparams: dict) -> tuple[str, list[str]]:
    """Return patched source plus a list of human warnings."""
    warnings: list[str] = []
    block = find_update_block(source, 0)
    payload = py_dumps(rcparams)
    injection = f"\n# ---- injected global style template (plot-batch-style) ----\nplt.rcParams.update(\n{payload}\n)\n# ---- end injected ----\n"
    if block:
        start, end = block
        patched = source[:end] + injection + source[end:]
        if find_update_block(source, end + 1):
            warnings.append("later rcParams.update overrides the injected template")
    else:
        marker = re.search(r"^import matplotlib[^\n]*$", source, re.M)
        if not marker:
            marker = re.search(r"^import numpy[^\n]*$", source, re.M)
        if marker:
            patched = source[: marker.end()] + "\n" + injection + source[marker.end() :]
            if find_update_block(source, marker.end() + 1):
                warnings.append("later rcParams.update overrides the injected template")
        else:
            patched = injection + source
    return patched, warnings


def force_dpi(source: str, dpi: int) -> str:
    def _sub(match: re.Match) -> str:
        return f"{match.group(1)}dpi={dpi}{match.group(3)}"

    pattern = re.compile(r"(savefig\([^)]*?dpi\s*=\s*)(\d+)(\s*,|\))")
    return pattern.sub(_sub, source)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rcparams", required=True, help="JSON template or journal alias")
    ap.add_argument("--files", nargs="+", required=True)
    ap.add_argument("--out-dir", type=Path, default=Path("unified_figs"))
    ap.add_argument("--inplace", action="store_true")
    ap.add_argument("--force-dpi", type=int, help="rewrite dpi=... inside savefig calls")
    args = ap.parse_args()

    rcparams = parse_rcparams(args.rcparams)
    for file in args.files:
        src = Path(file)
        if not src.exists():
            print(f"skip (missing): {src}")
            continue
        text = src.read_text(encoding="utf-8")
        patched, warnings = inject_rcparams(text, rcparams)
        if args.force_dpi:
            patched = force_dpi(patched, args.force_dpi)
        dest = src if args.inplace else args.out_dir / src.name
        if not args.inplace:
            dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(patched, encoding="utf-8")
        status = "inplace" if args.inplace else f"-> {dest}"
        print(f"patched {src} {status}")
        for w in warnings:
            print(f"  warning: {w} ({src.name})")


if __name__ == "__main__":
    main()
