#!/usr/bin/env python3
"""Paired bar chart + paired t-test with significance stars.

Wide input (default):
    subject, baseline, method
Long input (--long):
    subject, condition, value      (condition must have exactly two levels)

Examples:
    python paired_bar_ttest.py --wide data.csv --col-a baseline \\
        --col-b method --out paired.png --table paired_stats.csv
    python paired_bar_ttest.py --long long.csv --subject subject \\
        --condition condition --value value --journal nature
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.patches as mpatches  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import stats  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
import plot_utils  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    data = ap.add_mutually_exclusive_group(required=True)
    data.add_argument("--wide", help="wide CSV/TSV")
    data.add_argument("--long", help="long CSV/TSV")
    ap.add_argument("--col-a", default=None, help="first condition column (wide)")
    ap.add_argument("--col-b", default=None, help="second condition column (wide)")
    ap.add_argument("--subject", default="subject")
    ap.add_argument("--condition", default="condition")
    ap.add_argument("--value", default="value")
    ap.add_argument("--out", type=Path, default=Path("paired_bar.png"))
    ap.add_argument("--table", type=Path, default=Path("paired_stats.csv"))
    ap.add_argument("--ylabel", default="Value")
    ap.add_argument("--journal", default=None)
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    if args.wide:
        df = pd.read_csv(args.wide, sep=None, engine="python")
        col_a = args.col_a or df.columns[0]
        col_b = args.col_b or df.columns[1]
        a = pd.to_numeric(df[col_a], errors="coerce").to_numpy()
        b = pd.to_numeric(df[col_b], errors="coerce").to_numpy()
        labels = [col_a, col_b]
    else:
        df = pd.read_csv(args.long, sep=None, engine="python")
        levels = sorted(df[args.condition].unique())
        if len(levels) != 2:
            raise SystemExit(f"expected exactly two conditions, got {levels}")
        piv = df.pivot(index=args.subject, columns=args.condition, values=args.value)
        piv = piv.apply(pd.to_numeric, errors="coerce").dropna()
        a = piv[levels[0]].to_numpy()
        b = piv[levels[1]].to_numpy()
        labels = [str(levels[0]), str(levels[1])]

    ok = np.isfinite(a) & np.isfinite(b)
    a, b = a[ok], b[ok]
    n = len(a)
    if n < 2:
        raise SystemExit("need >= 2 paired observations")
    diff = b - a
    t_stat, p = stats.ttest_rel(b, a)
    dfree = n - 1
    se_diff = diff.std(ddof=1) / math.sqrt(n)
    t_crit = stats.t.ppf(0.975, dfree)
    ci_lo, ci_hi = diff.mean() - t_crit * se_diff, diff.mean() + t_crit * se_diff
    cohen_dz = diff.mean() / diff.std(ddof=1) if diff.std(ddof=1) > 0 else float("nan")
    stars = plot_utils.significance_stars(p)

    # ---- stats table ----------------------------------------------------- #
    rows = []
    for label, arr in zip(labels, (a, b)):
        rows.append(
            {
                "condition": label,
                "n": n,
                "mean": arr.mean(),
                "sd": arr.std(ddof=1),
                "sem": arr.std(ddof=1) / math.sqrt(n),
                "statistic": "",
                "value": "",
            }
        )
    rows.append(
        {
            "condition": f"difference ({labels[1]} - {labels[0]})",
            "n": n,
            "mean": diff.mean(),
            "sd": diff.std(ddof=1),
            "sem": se_diff,
            "statistic": "",
            "value": "",
        }
    )
    test_values = [
        ("t", t_stat),
        ("df", dfree),
        ("p", p),
        ("stars", stars),
        ("mean_diff", diff.mean()),
        ("ci_low", ci_lo),
        ("ci_high", ci_hi),
        ("cohen_dz", cohen_dz),
    ]
    for name, value in test_values:
        rows.append(
            {
                "condition": "",
                "n": "",
                "mean": "",
                "sd": "",
                "sem": "",
                "statistic": name,
                "value": value,
            }
        )
    table = pd.DataFrame(rows)
    args.table.parent.mkdir(parents=True, exist_ok=True)
    table.to_csv(args.table, index=False)

    # ---- plot ------------------------------------------------------------ #
    if args.journal:
        plt.rcParams.update(plot_utils.journal_rcparams(args.journal))
    else:
        plt.rcParams.update(
            {
                "font.family": "sans-serif",
                "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
                "font.size": 8,
                "axes.linewidth": 0.75,
                "savefig.dpi": args.dpi,
            }
        )

    means = [a.mean(), b.mean()]
    sems = [a.std(ddof=1) / math.sqrt(n), b.std(ddof=1) / math.sqrt(n)]
    colors = ["#A8C8E8", "#1B3D6E"]
    fig, ax = plt.subplots(figsize=(2.6, 3.2))
    bars = ax.bar(range(2), means, yerr=sems, capsize=3.5, width=0.56, color=colors,
                  edgecolor="black", linewidth=0.7, error_kw=dict(lw=0.8))
    if n <= 40:
        rng = np.random.default_rng(1)
        jit_a = rng.uniform(-0.10, 0.10, n)
        ax.scatter(np.full(n, 0) + jit_a, a, s=12, color="#333333", alpha=0.55, zorder=3)
        ax.scatter(np.full(n, 1) + jit_a, b, s=12, color="#333333", alpha=0.55, zorder=3)
        for x0, x1, y0, y1 in zip(np.full(n, 0) + jit_a, np.full(n, 1) + jit_a, a, b):
            ax.plot([x0, x1], [y0, y1], color="#888888", lw=0.4, alpha=0.4, zorder=2)
    ax.set_xticks(range(2))
    ax.set_xticklabels(labels)
    ax.set_ylabel(args.ylabel)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.tick_params(axis="x", length=0)

    ymax = max(a.max(), b.max())
    ylim_top = ymax * 1.15
    ax.set_ylim(0, ylim_top)
    # bracket + stars
    y_bracket = ymax * 1.05
    ax.plot([0, 0, 1, 1], [y_bracket, y_bracket * 1.01, y_bracket * 1.01, y_bracket],
            color="black", lw=0.8)
    ax.text(0.5, y_bracket * 1.04, f"p = {p:.3g} {stars}", ha="center",
            va="bottom", fontsize=8)
    fig.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=args.dpi, facecolor="white")
    plt.close(fig)
    print(f"paired bar: {args.out}")
    print(f"stats table: {args.table}")
    print(f"paired t({dfree}) = {t_stat:.3f}, p = {p:.4g} {stars}; "
          f"mean diff = {diff.mean():.3f} (95% CI {ci_lo:.3f}-{ci_hi:.3f})")


if __name__ == "__main__":
    main()
