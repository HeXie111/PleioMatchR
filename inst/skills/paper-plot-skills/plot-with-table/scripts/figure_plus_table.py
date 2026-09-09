#!/usr/bin/env python3
"""Figure + styled statistics table from a method-level results CSV.

Example:
    python figure_plus_table.py --input mr_methods.csv \\
        --out-dir results/ --journal nature

Input column aliases are auto-detected (see plot-with-table/SKILL.md); explicit
overrides available through the CLI.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
import plot_utils  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def _pick(df: pd.DataFrame, aliases, explicit):
    if explicit:
        return explicit
    for col in aliases:
        if col in df.columns:
            return col
    raise ValueError(f"column not found; tried {aliases} in {list(df.columns)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", required=True)
    ap.add_argument("--out-dir", type=Path, default=Path("results"))
    ap.add_argument("--journal", default=None)
    ap.add_argument("--style", choices=["forest", "beta"], default="forest")
    ap.add_argument("--method-col")
    ap.add_argument("--nsnp-col")
    ap.add_argument("--effect-col")
    ap.add_argument("--lower-col")
    ap.add_argument("--upper-col")
    ap.add_argument("--p-col")
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    df = pd.read_csv(args.input, sep=None, engine="python")
    method_col = _pick(df, ["method", "method_name", "Method"], args.method_col)
    try:
        nsnp_col = args.nsnp_col or _pick(df, ["nsnp", "n_snp", "n"], None)
    except ValueError:
        nsnp_col = None
    effect_col = _pick(df, ["or", "hr", "b", "beta", "est"], args.effect_col)
    lower_col = _pick(
        df, ["or_lci95", "or_uci95", "lci", "uci", "lower", "ci_low"], args.lower_col
    )
    upper_col = _pick(
        df, ["or_uci95", "or_lci95", "uci", "lci", "upper", "ci_high"], args.upper_col
    )
    p_col = _pick(df, ["pval", "p", "pvalue", "P"], args.p_col)

    effect = pd.to_numeric(df[effect_col], errors="coerce")
    lower = pd.to_numeric(df[lower_col], errors="coerce")
    upper = pd.to_numeric(df[upper_col], errors="coerce")
    pval = pd.to_numeric(df[p_col], errors="coerce")
    nsnp = pd.to_numeric(df[nsnp_col], errors="coerce") if nsnp_col else None
    ok = effect.notna() & lower.notna() & upper.notna() & pval.notna()
    df = df[ok].reset_index(drop=True)

    log_scale = args.style == "forest" and df[effect_col].abs().mean() > 2.0
    args.out_dir.mkdir(parents=True, exist_ok=True)
    if args.journal:
        plt.rcParams.update(plot_utils.journal_rcparams(args.journal))
    else:
        plt.rcParams.update(
            {
                "font.family": "sans-serif",
                "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
                "font.size": 8,
                "savefig.dpi": args.dpi,
            }
        )

    # ---- figure ---------------------------------------------------------- #
    k = len(df)
    fig, ax = plt.subplots(figsize=(6.2, max(1.8, 0.5 * k + 0.7)))
    rows_pos = np.arange(k)[::-1] + 1
    for i, (idx, row) in enumerate(df.iterrows()):
        y = k - i
        e, lo, hi = row[effect_col], row[lower_col], row[upper_col]
        sig = row[p_col] < 0.05
        color = "#0072B2" if sig else "#666666"
        ax.plot([lo, hi], [y, y], color="#4D4D4D", lw=1.1)
        ax.add_patch(
            plt.Polygon(
                [(lo, y), (e, y + 0.18), (hi, y), (e, y - 0.18)],
                facecolor=color,
                edgecolor="black",
                lw=0.6,
                closed=True,
            )
        )
        ax.text(
            1.01,
            y,
            f"{e:.2f} ({lo:.2f}-{hi:.2f})   p={row[p_col]:.3g}"
            + (" *" if sig else ""),
            transform=ax.get_yaxis_transform(),
            va="center",
            fontsize=7,
        )
    if log_scale:
        allv = np.concatenate([lower, upper, effect])
        ax.set_xscale("log")
        ax.set_xlim(allv.min() * 0.9, allv.max() * 1.1)
        ref = 1.0
    else:
        ref = 0.0
    ax.axvline(ref, color="#888888", ls="--", lw=0.7)
    ax.set_yticks(rows_pos)
    ax.set_yticklabels(df[method_col], fontsize=7)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.tick_params(axis="y", length=0)
    ax.set_xlabel("OR (95% CI)" if log_scale else "Effect (95% CI)")
    fig.tight_layout()
    fig_path = args.out_dir / "forest_methods.png"
    fig.savefig(fig_path, dpi=args.dpi, facecolor="white")
    plt.close(fig)

    # ---- styled table ---------------------------------------------------- #
    table_rows = []
    for _, row in df.iterrows():
        sig = row[p_col] < 0.05
        display = (
            f"{row[effect_col]:.3f} ({row[lower_col]:.3f}-{row[upper_col]:.3f})"
            f"{' *' if sig else ''}"
        )
        entry = {
            "method": row[method_col],
            "effect (95% CI)": display,
            "p": f"{row[p_col]:.3g}",
        }
        if nsnp is not None:
            entry["nsnp"] = str(int(row[nsnp_col])) if not pd.isna(row[nsnp_col]) else ""
        table_rows.append(entry)
    formatted = pd.DataFrame(table_rows)
    formatted.to_csv(args.out_dir / "formatted_table.csv", index=False)

    tfig = plt.figure(figsize=(max(4.0, len(formatted.columns) * 1.3), 0.55 + 0.34 * len(formatted)))
    tax = tfig.add_subplot(111)
    tax.axis("off")
    cell_text = [formatted.columns.tolist()] + formatted.astype(str).values.tolist()
    tbl = tax.table(cellText=cell_text, loc="center", cellLoc="left")
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(7)
    tbl.scale(1, 1.4)
    for j in range(len(formatted.columns)):
        cell = tbl[0, j]
        cell.set_facecolor("#EEEEEE")
        cell.set_text_props(fontweight="bold")
    for i, (_, row) in enumerate(df.iterrows(), start=1):
        if row[p_col] < 0.05:
            for j in range(len(formatted.columns)):
                tbl[i, j].set_facecolor("#FFF7E6")
    tfig.savefig(args.out_dir / "table.png", dpi=args.dpi, facecolor="white",
                 bbox_inches="tight")
    plt.close(tfig)

    print(f"figure: {fig_path}")
    print(f"table png: {args.out_dir / 'table.png'}")
    print(f"table csv: {args.out_dir / 'formatted_table.csv'}")


if __name__ == "__main__":
    main()
