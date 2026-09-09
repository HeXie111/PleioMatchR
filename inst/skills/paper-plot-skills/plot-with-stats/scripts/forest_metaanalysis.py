#!/usr/bin/env python3
"""Forest plot with fixed/random-effects meta-analysis.

Reads a per-study table (CSV/TSV) and produces:
  * pooled effect (fixed inverse-variance and/or DerSimonian-Laird random)
  * Q statistic / p(heterogeneity), I^2
  * per-study and pooled rows in a stats CSV
  * journal-grade forest PNG/TIFF

Data contract (any naming works via --*-col):
    id | est | se            (est = beta, log-OR or log-HR; scale defines display)
    id | lower | upper       (already on effect scale)

PleioMatchR / TwoSampleMR friendly aliases are matched automatically:
    id: sentinel_id, SNP, id, locus
    est: aligned_beta, beta, b, logor, log_OR, effect
    se : aligned_se, se, std_error, standard_error

Examples:
    python forest_metaanalysis.py --input mr_locus.tsv --scale beta \\
        --out forest.png --table meta_stats.csv
    python forest_metaanalysis.py --input ivw_snp.csv --id-col SNP \\
        --est-col b --se-col se --scale or --method both --journal nature
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

ID_ALIASES = ["sentinel_id", "SNP", "id", "locus", "rsid", "study"]
EST_ALIASES = ["aligned_beta", "beta", "b", "logor", "log_OR", "effect", "logHR"]
SE_ALIASES = ["aligned_se", "se", "std_error", "standard_error", "SE"]
LOW_ALIASES = ["lower", "ci_low", "lci", "or_lci95", "l95"]
HIGH_ALIASES = ["upper", "ci_high", "uci", "or_uci95", "u95"]


def pick_col(columns, aliases, label):
    for col in aliases:
        if col in columns:
            return col
    raise ValueError(f"cannot find a {label} column in {list(columns)}")


def meta_analyze(beta: np.ndarray, se: np.ndarray) -> dict:
    w = 1.0 / np.maximum(se, 1e-12) ** 2
    k = len(beta)
    b_fixed = float(np.sum(w * beta) / np.sum(w))
    se_fixed = float(1.0 / math.sqrt(np.sum(w)))
    q = float(np.sum(w * (beta - b_fixed) ** 2))
    df = max(k - 1, 1)
    p_het = float(stats.chi2.sf(q, df))
    denom = float(np.sum(w) - np.sum(w**2) / np.sum(w))
    tau2 = max(0.0, (q - df) / denom) if denom > 0 else 0.0
    i2 = 100.0 * max(0.0, (q - df) / q) if q > 0 else 0.0
    w_r = 1.0 / (np.maximum(se, 1e-12) ** 2 + tau2)
    b_random = float(np.sum(w_r * beta) / np.sum(w_r))
    se_random = float(1.0 / math.sqrt(np.sum(w_r)))
    return {
        "k": k,
        "q": q,
        "df": df,
        "p_heterogeneity": p_het,
        "tau2": tau2,
        "i2": i2,
        "fixed": {"est": b_fixed, "se": se_fixed},
        "random": {"est": b_random, "se": se_random},
    }


def ci_of(est: float, se: float) -> tuple[float, float]:
    return est - 1.96 * se, est + 1.96 * se


def draw_forest(
    ids,
    est_log,
    se,
    out: Path,
    *,
    meta: dict,
    methods=("random", "fixed"),
    scale: str = "beta",
    hits=None,
    xlabel: str = "Effect (95% CI)",
    title: str = "",
    journal: str | None = None,
    dpi: int = 300,
):
    """est_log/ci are on the log scale for OR/HR, raw for beta."""
    k = len(est_log)
    if journal:
        rc = plot_utils.journal_rcparams(journal)
        plt.rcParams.update(rc)
    else:
        plt.rcParams.update(
            {
                "font.family": "sans-serif",
                "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
                "font.size": 8,
                "axes.linewidth": 0.75,
                "savefig.dpi": dpi,
            }
        )

    fig, ax = plt.subplots(figsize=(7.2, max(2.2, 0.42 * (k + 2))))
    order = list(range(k - 1, -1, -1))
    x_all = []
    for idx in range(k):
        lo, hi = ci_of(est_log[idx], se[idx])
        y = k - idx
        color = "#0072B2"
        fill = True
        if hits is not None:
            fill = bool(hits[idx])
        marker = "s" if fill else "s"
        edge = color if not fill else color
        ax.plot([lo, hi], [y, y], color="#4D4D4D", lw=1.2, zorder=3)
        ax.scatter(
            [est_log[idx]],
            [y],
            marker=marker,
            s=38,
            facecolor=color if fill else "white",
            edgecolor=edge,
            lw=1.0,
            zorder=4,
        )
        x_all += [lo, hi, est_log[idx]]
        w_pct = 100.0 * (1.0 / se[idx] ** 2) / np.sum(1.0 / se**2)
        ax.text(
            1.012,
            y,
            f"{w_pct:5.1f}%",
            transform=ax.get_yaxis_transform(),
            va="center",
            fontsize=7.2,
        )

    summary_rows = []
    for j, method in enumerate(methods):
        m = meta[method]
        y = k + 1 + j * 0.55
        lo, hi = ci_of(m["est"], m["se"])
        x_all += [lo, hi]
        summary_rows.append((y, method, m, lo, hi))

    if scale in ("or", "hr"):
        xmin, xmax = min(x_all), max(x_all)
        pad = (xmax - xmin) * 0.15 or 0.3
        ax.set_xlim(math.exp(xmin - pad), math.exp(xmax + pad))
        ax.set_xscale("log")
        ref = 1.0
    else:
        xmin, xmax = min(x_all), max(x_all)
        pad = (xmax - xmin) * 0.1 or 0.2
        ax.set_xlim(xmin - pad, xmax + pad)
        ref = 0.0

    ax.axvline(ref, color="#666666", ls="--", lw=0.8, zorder=1)
    for y, method, m, lo, hi in summary_rows:
        ax.plot([lo, hi], [y, y], color="black", lw=1.4, zorder=5)
        # diamond
        dh = 0.22
        ax.add_patch(
            mpatches.Polygon(
                [(lo, y), (m["est"], y + dh), (hi, y), (m["est"], y - dh)],
                closed=True,
                facecolor="black",
                edgecolor="black",
                zorder=6,
            )
        )
        label = "Random-effects" if method == "random" else "Fixed-effects"
        ax.text(
            1.012,
            y,
            f"{label}   {math.exp(m['est']) if scale in ('or','hr') else m['est']:.3f} "
            f"({math.exp(lo) if scale in ('or','hr') else lo:.3f}–"
            f"{math.exp(hi) if scale in ('or','hr') else hi:.3f})",
            transform=ax.get_yaxis_transform(),
            va="center",
            fontsize=7.2,
            fontweight="bold",
        )

    ymax = k + 1 + (len(methods) - 1) * 0.55 + 0.7
    ax.set_ylim(0.4, ymax)
    ax.set_yticks(range(1, k + 1))
    ax.set_yticklabels(ids, fontsize=7.2)
    ax.set_xlabel(xlabel, fontsize=8)
    if title:
        ax.set_title(title, fontsize=9, pad=8)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.tick_params(axis="y", length=0)
    ax.yaxis.grid(False)

    stat_txt = (
        f"I2 = {meta['i2']:.1f}%   Q({int(meta['df'])}) = {meta['q']:.2f}   "
        f"p_het = {meta['p_heterogeneity']:.3f}   k = {meta['k']}"
    )
    ax.text(
        0.0,
        -0.055,
        stat_txt,
        transform=ax.transAxes,
        fontsize=6.8,
        color="#444444",
    )
    fig.tight_layout()
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=dpi, facecolor="white")
    plt.close(fig)
    return fig


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", required=True)
    ap.add_argument("--id-col", help="explicit id column")
    ap.add_argument("--est-col", help="explicit effect column (log scale for OR/HR)")
    ap.add_argument("--se-col", help="explicit SE column")
    ap.add_argument("--lower-col", "--lci-col", dest="lower_col")
    ap.add_argument("--upper-col", "--uci-col", dest="upper_col")
    ap.add_argument("--hit-col", help="optional boolean hit column (fill squares)")
    ap.add_argument("--scale", choices=["beta", "or", "hr"], default="beta")
    ap.add_argument("--method", choices=["random", "fixed", "both"], default="random")
    ap.add_argument("--out", type=Path, default=Path("forest.png"))
    ap.add_argument("--table", type=Path, default=Path("meta_stats.csv"))
    ap.add_argument("--title", default="")
    ap.add_argument("--effect-label", default=None)
    ap.add_argument("--journal", default=None)
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    df = pd.read_csv(args.input, sep=None, engine="python")
    id_col = args.id_col or pick_col(df.columns, ID_ALIASES, "id")
    if args.est_col and args.se_col:
        est = pd.to_numeric(df[args.est_col], errors="coerce").to_numpy()
        se = pd.to_numeric(df[args.se_col], errors="coerce").to_numpy()
    elif args.lower_col and args.upper_col:
        lo = pd.to_numeric(df[args.lower_col], errors="coerce").to_numpy()
        hi = pd.to_numeric(df[args.upper_col], errors="coerce").to_numpy()
        if args.scale in ("or", "hr"):
            est = 0.5 * (np.log(lo) + np.log(hi))
            se = (np.log(hi) - np.log(lo)) / (2 * 1.96)
        else:
            est = 0.5 * (lo + hi)
            se = (hi - lo) / (2 * 1.96)
    else:
        est_col = args.est_col or pick_col(df.columns, EST_ALIASES, "est")
        se_col = args.se_col or pick_col(df.columns, SE_ALIASES, "se")
        est = pd.to_numeric(df[est_col], errors="coerce").to_numpy()
        se = pd.to_numeric(df[se_col], errors="coerce").to_numpy()

    ok = np.isfinite(est) & np.isfinite(se) & (se > 0)
    df = df[ok].reset_index(drop=True)
    est, se = est[ok], se[ok]
    ids = df[id_col].astype(str).tolist()
    if len(df) < 2:
        raise SystemExit("need at least two valid studies for a meta-analysis")

    meta = meta_analyze(est, se)
    methods = ["random", "fixed"] if args.method == "both" else [args.method]
    scale_label = {"beta": "Effect (beta)", "or": "Odds ratio (95% CI)", "hr": "Hazard ratio (95% CI)"}
    hits = (
        pd.to_numeric(df[args.hit_col], errors="coerce").fillna(0).astype(bool).to_numpy()
        if args.hit_col
        else None
    )
    draw_forest(
        ids,
        est,
        se,
        args.out,
        meta=meta,
        methods=methods,
        scale=args.scale,
        hits=hits,
        xlabel=args.effect_label or scale_label[args.scale],
        title=args.title,
        journal=args.journal,
        dpi=args.dpi,
    )

    # ---- stats table ----------------------------------------------------- #
    out_rows = []
    total_w = np.sum(1.0 / se**2)
    for i, row_id in enumerate(ids):
        lo, hi = ci_of(est[i], se[i])
        p = 2 * stats.norm.sf(abs(est[i] / se[i]))
        rec = {
            "id": row_id,
            "type": "study",
            "est": est[i],
            "se": se[i],
            "ci_low": lo,
            "ci_high": hi,
            "p": p,
            "weight_pct": 100.0 * (1.0 / se[i] ** 2) / total_w,
        }
        if args.scale in ("or", "hr"):
            rec.update({"or_hr": math.exp(est[i]), "or_hr_lci": math.exp(lo), "or_hr_uci": math.exp(hi)})
        if hits is not None:
            rec["hit"] = bool(hits[i])
        out_rows.append(rec)
    for method in methods:
        m = meta[method]
        lo, hi = ci_of(m["est"], m["se"])
        rec = {
            "id": method,
            "type": "pooled",
            "est": m["est"],
            "se": m["se"],
            "ci_low": lo,
            "ci_high": hi,
            "p": 2 * stats.norm.sf(abs(m["est"] / m["se"])),
            "weight_pct": np.nan,
            "i2": meta["i2"],
            "p_heterogeneity": meta["p_heterogeneity"],
            "tau2": meta["tau2"],
        }
        if args.scale in ("or", "hr"):
            rec.update({"or_hr": math.exp(m["est"]), "or_hr_lci": math.exp(lo), "or_hr_uci": math.exp(hi)})
        out_rows.append(rec)
    out_df = pd.DataFrame(out_rows)
    args.table.parent.mkdir(parents=True, exist_ok=True)
    out_df.to_csv(args.table, index=False)
    print(f"forest plot: {args.out}")
    print(f"stats table: {args.table}")
    print(
        f"random pooled: {meta['random']['est']:.4f} "
        f"(95% CI {meta['random']['est'] - 1.96 * meta['random']['se']:.4f}-"
        f"{meta['random']['est'] + 1.96 * meta['random']['se']:.4f}), "
        f"I2={meta['i2']:.1f}%, p_het={meta['p_heterogeneity']:.3f}"
    )


if __name__ == "__main__":
    main()
