#!/usr/bin/env python3
"""Volcano plot from per-feature differential statistics.

Input CSV/TSV columns: gene (or feature id), log2fc, pvalue (or padj).
When raw counts are available use the bundled DESeq2 R template first
(volcano_deseq2.R) and feed its output here.

Examples:
    python volcano_de.py --stats de_table.csv --out volcano.png \\
        --table de_annotated.csv --label-top 20
"""

from __future__ import annotations

import argparse
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


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--stats", required=True)
    ap.add_argument("--gene-col", default=None)
    ap.add_argument("--log2fc-col", default=None)
    ap.add_argument("--pvalue-col", default=None)
    ap.add_argument("--padj-col", default=None, help="precomputed adjusted p column")
    ap.add_argument("--fc-threshold", type=float, default=1.0)
    ap.add_argument("--p-threshold", type=float, default=0.05)
    ap.add_argument("--label-top", type=int, default=20)
    ap.add_argument("--out", type=Path, default=Path("volcano.png"))
    ap.add_argument("--table", type=Path, default=Path("de_annotated.csv"))
    ap.add_argument("--title", default="")
    ap.add_argument("--journal", default=None)
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    df = pd.read_csv(args.stats, sep=None, engine="python")
    gene_col = args.gene_col or next(
        (c for c in ["gene", "Gene", "feature", "id", "symbol"] if c in df.columns),
        df.columns[0],
    )
    lfc_col = args.log2fc_col or next(
        (c for c in ["log2fc", "log2FoldChange", "logFC", "log2_fc"] if c in df.columns),
        None,
    )
    p_col = args.pvalue_col or next(
        (c for c in ["pvalue", "p.value", "p", "PValue"] if c in df.columns),
        None,
    )
    if lfc_col is None or p_col is None:
        raise SystemExit("need log2fc and pvalue columns; see --help")
    df[gene_col] = df[gene_col].astype(str)
    lfc = pd.to_numeric(df[lfc_col], errors="coerce").to_numpy()
    pv = pd.to_numeric(df[p_col], errors="coerce").to_numpy()
    ok = np.isfinite(lfc) & np.isfinite(pv) & (pv > 0)
    df = df[ok].reset_index(drop=True)
    lfc, pv = lfc[ok], pv[ok]

    if args.padj_col and args.padj_col in df.columns:
        padj = pd.to_numeric(df[args.padj_col], errors="coerce").fillna(1.0).to_numpy()
    else:
        padj = np.array(plot_utils.bh_adjust(pv.tolist()))
    df["padj"] = padj
    df["neg_log10p"] = -np.log10(pv)

    up = (lfc > args.fc_threshold) & (padj < args.p_threshold)
    down = (lfc < -args.fc_threshold) & (padj < args.p_threshold)
    df["direction"] = np.where(up, "up", np.where(down, "down", "ns"))

    # top-N: most significant among the regulated features
    regulated = df[up | down].copy()
    if len(regulated):
        regulated["rank"] = regulated["padj"].rank()
        top = regulated.nsmallest(args.label_top, "padj")
    else:
        top = pd.DataFrame(columns=df.columns)

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

    fig, ax = plt.subplots(figsize=(4.8, 4.0))
    colors = {"up": "#D55E00", "down": "#0072B2", "ns": "#B3B3B3"}
    for direction in ("ns", "down", "up"):
        mask = df["direction"] == direction
        ax.scatter(lfc[mask], -np.log10(pv[mask]), s=7, color=colors[direction],
                   label=direction, alpha=0.7, linewidths=0)
    ax.axhline(-np.log10(args.p_threshold), color="#666666", lw=0.7, ls="--")
    ax.axvline(args.fc_threshold, color="#666666", lw=0.7, ls="--")
    ax.axvline(-args.fc_threshold, color="#666666", lw=0.7, ls="--")
    for _, row in top.iterrows():
        ax.text(
            row[lfc_col],
            -np.log10(row[p_col]),
            row[gene_col],
            fontsize=5.8,
            color="#111111",
            alpha=0.85,
        )
    ax.set_xlabel("log2 fold change")
    ax.set_ylabel("-log10(p-value)")
    ax.legend(frameon=False, fontsize=7, loc="upper left")
    if args.title:
        ax.set_title(args.title, fontsize=9)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    fig.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=args.dpi, facecolor="white")
    plt.close(fig)

    args.table.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.table, index=False)
    print(f"volcano: {args.out}")
    print(f"annotated table: {args.table}")
    print(f"up={int(up.sum())} down={int(down.sum())} ns={int((~up & ~down).sum())}")


if __name__ == "__main__":
    main()
