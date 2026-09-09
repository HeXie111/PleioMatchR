#!/usr/bin/env python3
"""Assemble independent figures into a labelled multi-panel composite.

Examples:
    python make_panel.py --images a.png b.png c.png d.png --layout 2x2 \
        --out figure1.tiff --dpi 600
    python make_panel.py --images p1.png p2.png p3.png --layout 1x3 \
        --labels "A B C" --out panel.png --journal cell
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
import plot_utils  # noqa: E402


def trim_white(img: Image.Image, tol: int = 12) -> Image.Image:
    bg = Image.new("RGB", img.size, (255, 255, 255))
    diff = Image.new("L", img.size)
    from PIL import ImageChops

    ImageChops.difference(img.convert("RGB"), bg).point(
        lambda v: 255 if v > tol else 0
    ).save(diff)
    bbox = diff.getbbox()
    return img.crop(bbox) if bbox else img


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--images", nargs="+", required=True)
    ap.add_argument("--layout", default=None, help="e.g. 2x2 or 3x2 (rows x cols)")
    ap.add_argument("--labels", default=None, help='space separated, e.g. "a b c d"')
    ap.add_argument("--out", type=Path, default=Path("panel.png"))
    ap.add_argument("--dpi", type=int, default=None)
    ap.add_argument("--journal", default=None, help="journal id for default dpi/width")
    ap.add_argument("--single-column", action="store_true")
    ap.add_argument("--trim", action="store_true", help="crop white borders")
    ap.add_argument("--label-size", type=float, default=14.0, help="letter font size pt")
    ap.add_argument("--pad-mm", type=float, default=2.0, help="gap between panels, mm")
    args = ap.parse_args()

    imgs = [trim_white(Image.open(p).convert("RGB")) if args.trim else Image.open(p).convert("RGB") for p in args.images]
    n = len(imgs)
    if args.layout:
        rows, cols = (int(x) for x in args.layout.lower().split("x"))
    else:
        cols = math.ceil(math.sqrt(n))
        rows = math.ceil(n / cols)
    if rows * cols < n:
        raise SystemExit(f"layout {rows}x{cols} is too small for {n} images")

    if args.labels:
        labels = args.labels.split()
    else:
        labels = [chr(ord("a") + i) for i in range(n)]
    if len(labels) < n:
        raise SystemExit("not enough labels")

    if args.dpi is None:
        spec = plot_utils.get_journal(args.journal) if args.journal else None
        args.dpi = spec["dpi"]["recommended"] if spec else 300

    # common cell canvas = max pixel size (letterbox smaller panels)
    cell_w = max(im.size[0] for im in imgs)
    cell_h = max(im.size[1] for im in imgs)
    pad = max(4, round(args.pad_mm / 25.4 * args.dpi))
    letter_mm = args.label_size / 72.0 * 25.4
    top_gutter = max(6, round((letter_mm + 2) / 25.4 * args.dpi))

    fig_w_px = cols * cell_w + (cols + 1) * pad
    fig_h_px = rows * cell_h + top_gutter + (rows + 1) * pad
    fig = plt.figure(figsize=(fig_w_px / args.dpi, fig_h_px / args.dpi), dpi=args.dpi)

    if args.journal:
        rc = plot_utils.journal_rcparams(args.journal)
        plt.rcParams.update(rc)
    fig.patch.set_facecolor("white")

    axes = []
    for idx, img in enumerate(imgs):
        r, c = divmod(idx, cols)
        # letterbox into the common cell
        canvas = Image.new("RGB", (cell_w, cell_h), (255, 255, 255))
        offset = ((cell_w - img.size[0]) // 2, (cell_h - img.size[1]) // 2)
        canvas.paste(img, offset)
        x0 = (pad + c * (cell_w + pad)) / fig_w_px
        y0 = 1.0 - (top_gutter + (r + 1) * (cell_h + pad)) / fig_h_px
        w = cell_w / fig_w_px
        h = cell_h / fig_h_px
        ax = fig.add_axes([x0, y0, w, h])
        ax.imshow(canvas)
        ax.set_axis_off()
        ax.text(
            0.005,
            0.995,
            f"({labels[idx]})",
            transform=ax.transAxes,
            ha="left",
            va="top",
            fontsize=args.label_size,
            fontweight="bold",
            color="black",
        )
        axes.append(ax)

    for idx in range(n, rows * cols):
        r, c = divmod(idx, cols)
        x0 = (pad + c * (cell_w + pad)) / fig_w_px
        y0 = 1.0 - (top_gutter + (r + 1) * (cell_h + pad)) / fig_h_px
        ax = fig.add_axes([x0, y0, cell_w / fig_w_px, cell_h / fig_h_px])
        ax.set_axis_off()
        ax.set_facecolor("white")

    fig.savefig(args.out, dpi=args.dpi, facecolor="white")
    plt.close(fig)
    print(f"panel written to {args.out} ({fig_w_px}x{fig_h_px} px @ {args.dpi} dpi)")


if __name__ == "__main__":
    main()
