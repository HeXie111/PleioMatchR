#!/usr/bin/env python3
"""Natural-language style search for the paper-plot-skills catalog.

Usage:
    python search_styles.py "Nature风格 森林图 meta分析"
    python search_styles.py "cell volcano" --top 3 --json

Outputs ranked styles with their template script and parameter reference.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared"))
import plot_utils  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("query", nargs="?", default="", help="natural-language query")
    ap.add_argument("--top", type=int, default=5)
    ap.add_argument("--json", action="store_true", help="print machine-readable JSON")
    args = ap.parse_args()

    if not args.query:
        # List the whole catalog as a fallback
        results = [
            {k: v for k, v in s.items() if not k.startswith("_")}
            for s in plot_utils.load_styles()
        ]
    else:
        results = plot_utils.search_styles(args.query, top_k=args.top)

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return

    for i, s in enumerate(results, 1):
        score = s.pop("_score", None)
        print(f"[{i}] {s['id']}  (score={score})")
        print(f"    {s['name']}")
        print(f"    script    : {s['script']}")
        print(f"    reference : {s['reference']}")
        print(f"    tags      : {', '.join(s['tags'][:6])}")
        print()


if __name__ == "__main__":
    main()
