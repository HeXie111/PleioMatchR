#!/usr/bin/env python3
"""Reverse-estimate data coordinates from image pixel positions.

The agent (or a vision model) marks the calibration extremes of the axes and
the pixel positions of points/series; this script maps pixels -> data values
using linear (or log10) axis calibrations and writes a CSV.

Calibration flags use image pixels with the origin at the TOP-LEFT corner
(py grows downwards), matching PIL / matplotlib imshow coordinates.

Example:
    python pixel_to_data.py --image fig.png --points points.csv \\
        --x-px 120 900 --x-val 0 100 \\
        --y-px 850 90  --y-val 0 50 \\
        --xlog --out estimated_data.csv --xunit days

points.csv columns: px, py [, label]   (one row per point to extract)
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from PIL import Image  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def _scale(px, p0, p1, v0, v1, use_log: bool) -> float:
    """px measured from the axis origin end of the axis."""
    if p1 == p0:
        return math.nan
    frac = (px - p0) / (p1 - p0)
    if use_log:
        if v0 <= 0 or v1 <= 0:
            return math.nan
        return math.exp(math.log(v0) + frac * (math.log(v1) - math.log(v0)))
    return v0 + frac * (v1 - v0)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--points", required=True, help="CSV with px,py[,label]")
    ap.add_argument("--image", type=Path, help="optional, for sanity checks")
    # x calibration: (pixel at low data end, pixel at high data end), data
    # values at those pixels. For un-inverted axes px_low < px_high normally.
    ap.add_argument("--x-px", nargs=2, type=float, required=True)
    ap.add_argument("--x-val", nargs=2, type=float, required=True)
    ap.add_argument("--y-px", nargs=2, type=float, required=True)
    ap.add_argument("--y-val", nargs=2, type=float, required=True)
    ap.add_argument("--xlog", action="store_true")
    ap.add_argument("--ylog", action="store_true")
    ap.add_argument("--out", type=Path, default=Path("estimated_data.csv"))
    ap.add_argument("--xunit", default="")
    ap.add_argument("--yunit", default="")
    args = ap.parse_args()

    pts = pd.read_csv(args.points, sep=None, engine="python")
    if "px" not in pts.columns or "py" not in pts.columns:
        raise SystemExit("points CSV needs px and py columns")
    label_col = "label" if "label" in pts.columns else None

    x_est, y_est, outside = [], [], []
    for _, row in pts.iterrows():
        # image y: top-left origin; data axes increase upward, so invert
        x = _scale(row["px"], args.x_px[0], args.x_px[1],
                   args.x_val[0], args.x_val[1], args.xlog)
        y = _scale(row["py"], args.y_px[0], args.y_px[1],
                   args.y_val[0], args.y_val[1], args.ylog)
        x_est.append(x)
        y_est.append(y)
        out = (
            not (min(args.x_px) <= row["px"] <= max(args.x_px))
            or not (min(args.y_px) <= row["py"] <= max(args.y_px))
        )
        outside.append(out)

    pts["est_x"] = x_est
    pts["est_y"] = y_est
    pts["outside_axis"] = outside
    if args.xunit:
        pts["est_x_unit"] = args.xunit
    if args.yunit:
        pts["est_y_unit"] = args.yunit

    args.out.parent.mkdir(parents=True, exist_ok=True)
    pts.to_csv(args.out, index=False)
    print(f"estimated data: {args.out} ({len(pts)} points)")
    if outside and any(outside):
        print("warning: some points fall outside the calibrated axis pixels; "
              "check outside_axis column")
    if label_col:
        print(pts[[label_col, "est_x", "est_y"]].head(8).to_string(index=False))
    else:
        print(pts[["px", "py", "est_x", "est_y"]].head(8).to_string(index=False))


if __name__ == "__main__":
    main()
