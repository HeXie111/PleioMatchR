#!/usr/bin/env python3
"""Kaplan-Meier survival curves with a log-rank test (Lancet/NEJM-ish style).

Input CSV/TSV:
    time, event, group        # event = 1 (event) / 0 (censored)

Examples:
    python survival_km.py --input km.csv --out km.png \\
        --table km_stats.csv --journal lancet
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
from scipy import stats  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
import plot_utils  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def km_estimate(time: np.ndarray, event: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    order = np.argsort(time)
    t = time[order]
    e = event[order]
    n = len(t)
    surv = np.ones(n + 1)
    tt = np.concatenate([[0.0], t])
    at_risk = n
    for i in range(n):
        # number of events at this time point (handles ties)
        j = i
        while j < n and t[j] == t[i]:
            j += 1
        n_events = int(e[i:j].sum())
        if at_risk > 0 and n_events:
            surv[i + 1 : j + 1] = surv[i] * ((at_risk - n_events) / at_risk)
        else:
            surv[i + 1 : j + 1] = surv[i]
        at_risk -= j - i
        i = j - 1
    return tt[: n + 1], surv[: n + 1]


def logrank_test(groups: dict[str, tuple[np.ndarray, np.ndarray]]) -> float:
    """Two-sample log-rank chi-square p-value."""
    # Event times are quantised so that ties (integer days, months, ...) are
    # grouped even when float arithmetic would make them unequal.
    def _event_times(g) -> np.ndarray:
        t, e = g
        return np.round(t[e == 1], decimals=9)

    all_t = sorted(
        {
            float(x)
            for g in groups.values()
            for x in _event_times(g)
        }
    )
    o, e, v = [], [], []
    labels = list(groups)
    g0, g1 = groups[labels[0]], groups[labels[1]]
    for t0 in all_t:
        d0 = int((np.round(g0[0][g0[1] == 1], 9) == t0).sum())
        d1 = int((np.round(g1[0][g1[1] == 1], 9) == t0).sum())
        n0 = int((g0[0] >= t0).sum())
        n1 = int((g1[0] >= t0).sum())
        d = d0 + d1
        n = n0 + n1
        if n <= 1 or d == 0:
            continue
        e.append(d * n0 / n)
        o.append(d0)
        v.append(n0 * n1 * d * (n - d) / (n * n * (n - 1)) if n > 1 else 0.0)
    oe = (sum(o) - sum(e)) ** 2
    var = sum(v)
    chi2 = oe / var if var > 0 else 0.0
    return float(stats.chi2.sf(chi2, 1))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", required=True)
    ap.add_argument("--time-col", default="time")
    ap.add_argument("--event-col", default="event")
    ap.add_argument("--group-col", default="group")
    ap.add_argument("--out", type=Path, default=Path("km_curve.png"))
    ap.add_argument("--table", type=Path, default=Path("km_stats.csv"))
    ap.add_argument("--journal", default=None)
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    df = pd.read_csv(args.input, sep=None, engine="python")
    time = pd.to_numeric(df[args.time_col], errors="coerce").to_numpy()
    event = pd.to_numeric(df[args.event_col], errors="coerce").to_numpy()
    groups = df[args.group_col].astype(str)
    ok = np.isfinite(time) & np.isfinite(event)
    df = df[ok]
    group_names = sorted(df[args.group_col].unique())
    if len(group_names) != 2:
        raise SystemExit("Kaplan-Meier style supports exactly two groups; "
                         "use R survival::survfit for multi-arm curves")
    km = {}
    raw = {}
    for g in group_names:
        sub = df[df[args.group_col] == g]
        t_arr = sub[args.time_col].to_numpy()
        e_arr = sub[args.event_col].to_numpy()
        raw[g] = (t_arr, e_arr)
        km[g] = km_estimate(t_arr, e_arr)
    p = logrank_test(raw)

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
    fig, ax = plt.subplots(figsize=(5.0, 4.0))
    colors = {"#0072B2", "#D55E00"}
    for g, col in zip(group_names, plot_utils.okabe_ito()[1:3]):
        tt, surv = km[g]
        ax.step(tt, surv, where="post", color=col, lw=1.5, label=g)
        # censoring ticks on the step plateau
        cens = df[(df[args.group_col] == g) & (df[args.event_col] == 0)]
        cens_times = cens[args.time_col].to_numpy()
        for ct in cens_times:
            idx = np.searchsorted(tt, ct, side="right") - 1
            ax.plot(ct, surv[min(idx, len(surv) - 1)], marker="|",
                    color=col, ms=5, mew=1.0)
    ax.set_xlabel("Time")
    ax.set_ylabel("Survival probability")
    ax.set_ylim(0, 1.03)
    ax.legend(frameon=False, fontsize=7)
    ax.text(0.98, 0.03, f"log-rank p = {p:.3g}", transform=ax.transAxes,
            ha="right", fontsize=8)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    fig.tight_layout()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.out, dpi=args.dpi, facecolor="white")
    plt.close(fig)

    rows = []
    for g in group_names:
        sub = df[df[args.group_col] == g]
        t, s = km[g]
        med_idx = np.argmax(s <= 0.5)
        median = float(t[med_idx]) if s[med_idx] <= 0.5 else math.nan
        rows.append(
            {
                "group": g,
                "n": len(sub),
                "events": int(sub[args.event_col].sum()),
                "median_survival": median,
                "logrank_p": p,
            }
        )
    pd.DataFrame(rows).to_csv(args.table, index=False)
    print(f"km curve: {args.out}")
    print(f"stats table: {args.table}")
    print(f"log-rank p = {p:.4g}")


if __name__ == "__main__":
    main()
