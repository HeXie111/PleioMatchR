#!/usr/bin/env python3
"""CVD-safety simulation and palette repair.

Examples:
    python simulate_and_fix.py --palette "#E41A1C,#377EB8,#4DAF4A" \
        --out preview.png --report report.json
    python simulate_and_fix.py --image figure.png --top 8 --out preview.png

Exit code is 1 when confusable pairs are found (useful for CI-ish checks).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from PIL import Image  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared"))
import plot_utils  # noqa: E402

KINDS = [("deutan", "Deuteranopia"), ("protan", "Protanopia"), ("tritan", "Tritanopia")]


def dominant_colors(image_path: Path, top_n: int) -> list[str]:
    """Extract the most frequent saturated colours from an image."""
    img = Image.open(image_path).convert("RGB")
    img.thumbnail((240, 240))
    pixels = list(img.getdata())
    counts: dict[tuple[int, int, int], int] = {}
    for r, g, b in pixels:
        key = (r // 24 * 24, g // 24 * 24, b // 24 * 24)
        counts[key] = counts.get(key, 0) + 1
    # drop near-white / near-black / low-saturation bins (axis text, panel
    # backgrounds and pastel fill areas are not categorical colours)
    ranked = []
    for (r, g, b), c in counts.items():
        mx, mn = max(r, g, b), min(r, g, b)
        if mn > 215 or mx < 120:
            continue  # near-white panel / near-black text
        sat = (mx - mn) / 255.0
        if sat < 0.12:
            continue  # grey
        # weight large saturated regions highly, but let point colours that
        # are heavily saturated compete with large pastel annotation fills
        ranked.append((c * sat**2, f"#{r:02x}{g:02x}{b:02x}"))
    ranked.sort(reverse=True)
    return [h for _, h in ranked[:top_n]]


def draw_preview(colors: list[str], out_path: Path) -> None:
    n = len(colors)
    fig, axes = plt.subplots(1 + len(KINDS), 1, figsize=(max(6.0, n * 0.8), 5.2))
    axes = [axes] if not isinstance(axes, list) and not hasattr(axes, "__iter__") else list(axes)
    labels = ["Original"] + [k[1] for k in KINDS]
    for ax, label in zip(axes, labels):
        ax.imshow(
            [[[int(c.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4)] for c in colors]],
            aspect="auto",
        )
        ax.set_yticks([])
        ax.set_xticks(range(n))
        ax.set_xticklabels(colors, fontsize=8)
        ax.set_title(label, fontsize=10, loc="left")
    fig.tight_layout()
    fig.savefig(out_path, dpi=200, facecolor="white")
    plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--palette", help="comma-separated hex colours")
    src.add_argument("--image", type=Path, help="image file to analyse")
    ap.add_argument("--top", type=int, default=8, help="dominant colours from image")
    ap.add_argument("--out", type=Path, default=Path("cvd_preview.png"))
    ap.add_argument("--report", type=Path, help="write JSON report")
    ap.add_argument("--threshold", type=float, default=25.0)
    args = ap.parse_args()

    if args.palette:
        colors = [c.strip() for c in args.palette.split(",") if c.strip()]
    else:
        colors = dominant_colors(args.image, args.top)
    if not colors:
        print("No saturated colours found to check.")
        return

    report = plot_utils.colorblind_report(colors, threshold=args.threshold)
    draw_preview(colors, args.out)
    print(f"preview written to {args.out}")
    print(f"palette: {', '.join(colors)}")
    print(f"confusable pairs under CVD simulation: {len(report['pairs'])}")
    for p in report["pairs"]:
        print(
            f"  [{p['i']}]{p['color_i']} vs [{p['j']}]{p['color_j']} "
            f"under {p['kind']}: dE={p['distance']} ({p['level']})"
        )
    if report["suggestions"]:
        print("suggested Okabe-Ito replacements:")
        for s in report["suggestions"]:
            print(f"  [{s['index']}] {s['original']} -> {s['replacement']}")
    if args.report:
        args.report.write_text(
            json.dumps({"palette": colors, **report}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    if report["pairs"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
