#!/usr/bin/env python3
"""Cross-library style transfer (matplotlib / seaborn / ggplot2 / origin).

Examples:
    python convert_style.py --style forest_meta_analysis --chart forest \\
        --target ggplot2 --data loci.csv --out forest.R
    python convert_style.py --style line_confidence_band --chart line \\
        --target seaborn --data curves.csv --xcol step --ycol value \\
        --groupcol method --errorcol se --out curves.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import pandas as pd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
import plot_utils  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


def _fmt_palette(colors: list[str]) -> str:
    return ", ".join(f'"{c}"' for c in colors)


def gen_ggplot2(chart: str, d: dict) -> str:
    pal = d["palette_py"]
    fam = d["font"]
    fontsize = d["fontsize"]
    data = d["data"]
    x, y, grp = d["xcol"], d["ycol"], d["groupcol"]
    se, lo, hi = d["errorcol"], d["locol"], d["hicol"]
    L = []
    L.append("library(ggplot2)")
    L.append(f"d <- read.csv({json.dumps(str(data))}, check.names = FALSE)")
    L.append(f"x <- {json.dumps(d['xcol'])}")
    L.append(f"y <- {json.dumps(d['ycol'])}")
    L.append(f"grp <- {json.dumps(d['groupcol'])}")
    if chart == "forest":
        if d.get("forest_from_se"):
            L.append(f"d$lo <- d[[x]] - 1.96 * d[[{json.dumps(d['secol'])}]]")
            L.append(f"d$hi <- d[[x]] + 1.96 * d[[{json.dumps(d['secol'])}]]")
            L.append('lo <- "lo"')
            L.append('hi <- "hi"')
        else:
            L.append(f"lo <- {json.dumps(d['locol'])}")
            L.append(f"hi <- {json.dumps(d['hicol'])}")
    elif d["errorcol"]:
        L.append(f"se <- {json.dumps(d['errorcol'])}")
    L.append(f"theme_paper <- function() {{")
    L.append(f"  theme_classic(base_size = {fontsize}, base_family = {json.dumps(fam)}) +")
    L.append("    theme(legend.position = 'right',")
    L.append("          panel.grid = element_blank(),")
    L.append("          axis.line = element_line(linewidth = 0.6))")
    L.append("}")
    if chart == "bar":
        L.append("p <- ggplot(d, aes(x = .data[[x]], y = .data[[y]], fill = .data[[grp]])) +")
        L.append("  geom_col(position = position_dodge(0.8), width = 0.7, colour = 'black', linewidth = 0.4)")
        if se:
            L.append("  geom_errorbar(aes(ymin = .data[[y]] - .data[[se]], ymax = .data[[y]] + .data[[se]]),")
            L.append("                position = position_dodge(0.8), width = 0.2)")
    elif chart == "line":
        L.append("p <- ggplot(d, aes(x = .data[[x]], y = .data[[y]], colour = .data[[grp]])) +")
        L.append("  geom_line(linewidth = 0.8)")
        if se:
            L.append("  geom_ribbon(aes(ymin = .data[[y]] - .data[[se]], ymax = .data[[y]] + .data[[se]],")
            L.append("                  fill = .data[[grp]]), alpha = 0.18, colour = NA)")
        L.append("  scale_fill_manual(values = c(%s))" % pal)
    elif chart == "scatter":
        L.append("p <- ggplot(d, aes(x = .data[[x]], y = .data[[y]], colour = .data[[grp]])) +")
        L.append("  geom_point(size = 1.6, alpha = 0.8)")
    elif chart == "forest":
        L.append("p <- ggplot(d, aes(x = .data[[x]], y = reorder(.data[[grp]], .data[[x]]))) +")
        L.append("  geom_vline(xintercept = %s, linetype = 2, colour = 'grey50')" % d["ref"])
        L.append("  geom_pointrange(aes(xmin = .data[[lo]], xmax = .data[[hi]]),")
        L.append("                   size = 0.35, fatten = 2)")
    else:
        raise SystemExit(f"unsupported chart {chart} for ggplot2")
    L.append("  scale_colour_manual(values = c(%s))" % pal)
    if chart != "forest":
        L.append("  scale_fill_manual(values = c(%s))" % pal)
    L.append("p <- p + theme_paper()")
    L.append("ggsave(%s, p, width = 7, height = 5, dpi = 300)" % json.dumps(d["fig_out"]))
    return "\n".join(L) + "\n"


def gen_seaborn(chart: str, d: dict) -> str:
    fam = d["font"]
    fs = d["fontsize"]
    pal = d["palette_py"]
    data = d["data"]
    x, y, grp = d["xcol"], d["ycol"], d["groupcol"]
    L = [
        "import matplotlib",
        "matplotlib.use('Agg')",
        "import matplotlib.pyplot as plt",
        "import pandas as pd",
        "import seaborn as sns",
        f"plt.rcParams.update({{'font.family': 'sans-serif', "
        f"'font.sans-serif': [{json.dumps(fam)}], 'font.size': {fs}, 'savefig.dpi': 300}})",
        f"df = pd.read_csv({json.dumps(str(data))})",
        f"sns.set_theme(style='white', rc={{'axes.linewidth': 0.6}})",
    ]
    if chart == "bar":
        L.append(f"sns.barplot(data=df, x={x!r}, y={y!r}, hue={grp!r}, palette=[{pal}], edgecolor='black', linewidth=0.4)")
        if d["errorcol"]:
            L.append("# paired error bars: pass precomputed ymin/ymax to err_kws, or use pointplot + errorbar")
    elif chart == "line":
        if d["errorcol"]:
            L.append(f"sns.lineplot(data=df, x={x!r}, y={y!r}, hue={grp!r}, palette=[{pal}], "
                     f"err_style='band', errorbar=('ci', 95))")
            L.append("# for precomputed SE columns use err_style='bars' with custom estimator or plot manually")
        else:
            L.append(f"sns.lineplot(data=df, x={x!r}, y={y!r}, hue={grp!r}, palette=[{pal}])")
    elif chart == "scatter":
        L.append(f"sns.scatterplot(data=df, x={x!r}, y={y!r}, hue={grp!r}, palette=[{pal}], alpha=0.75, s=18)")
    else:
        raise SystemExit("forest is not a seaborn-native chart; use ggplot2 or matplotlib")
    L.append("plt.tight_layout()")
    L.append(f"plt.savefig({json.dumps(d['fig_out'])}, dpi=300, facecolor='white')")
    return "\n".join(L) + "\n"


def gen_matplotlib(chart: str, d: dict) -> str:
    fam = d["font"]
    fs = d["fontsize"]
    pal = d["palette_py"]
    data = d["data"]
    x, y, grp = d["xcol"], d["ycol"], d["groupcol"]
    L = [
        "import matplotlib",
        "matplotlib.use('Agg')",
        "import matplotlib.pyplot as plt",
        "import pandas as pd",
        f"plt.rcParams.update({{'font.family': 'sans-serif', 'font.sans-serif': [{json.dumps(fam)}], "
        f"'font.size': {fs}, 'axes.linewidth': 0.6, 'savefig.dpi': 300}})",
        f"df = pd.read_csv({json.dumps(str(data))})",
        f"colors = [{pal}]",
    ]
    if chart == "forest":
        L += [
            "fig, ax = plt.subplots(figsize=(6.5, max(2.0, 0.4 * len(df))))",
            f"y = range(len(df), 0, -1)",
            f"ax.errorbar(df[{d['ycol']!r}], list(y), xerr=[df[{d['ycol']!r}] - df[{d['locol']!r}], "
            f"df[{d['hicol']!r}] - df[{d['ycol']!r}]], fmt='s', ms=5, color=colors[0], ecolor='#444444', capsize=3)",
            f"ax.axvline({d['ref']}, color='#888888', ls='--', lw=0.7)",
            f"ax.set_yticks(list(y)); ax.set_yticklabels(df[{d['groupcol']!r}], fontsize=7)",
            "for s in ('top', 'right'): ax.spines[s].set_visible(False)",
        ]
    else:
        L.append("fig, ax = plt.subplots(figsize=(6, 4))")
        if chart == "bar":
            L.append(f"for g, c in zip(sorted(df[{grp!r}].unique()), colors):")
            L.append(f"    sub = df[df[{grp!r}] == g]")
            L.append(f"    ax.bar(sub[{x!r}], sub[{y!r}], label=g, color=c, width=0.35, "
                     f"align='center')")
        elif chart == "line":
            L.append(f"for g, c in zip(sorted(df[{grp!r}].unique()), colors):")
            L.append(f"    sub = df[df[{grp!r}] == g].sort_values({x!r})")
            L.append(f"    ax.plot(sub[{x!r}], sub[{y!r}], color=c, label=g, lw=0.9)")
            if d["errorcol"]:
                L.append(f"    ax.fill_between(sub[{x!r}], sub[{y!r}] - sub[{d['errorcol']!r}], "
                         f"sub[{y!r}] + sub[{d['errorcol']!r}], color=c, alpha=0.15)")
        elif chart == "scatter":
            L.append(f"for g, c in zip(sorted(df[{grp!r}].unique()), colors):")
            L.append(f"    sub = df[df[{grp!r}] == g]")
            L.append(f"    ax.scatter(sub[{x!r}], sub[{y!r}], color=c, label=g, s=12, alpha=0.75)")
        L.append("ax.legend(frameon=False, fontsize=7)")
        L.append("for s in ('top', 'right'): ax.spines[s].set_visible(False)")
    L.append("fig.tight_layout()")
    L.append(f"fig.savefig({json.dumps(d['fig_out'])}, dpi=300, facecolor='white')")
    return "\n".join(L) + "\n"


def gen_origin(chart: str, d: dict) -> str:
    if chart not in ("bar", "line", "scatter"):
        raise SystemExit("origin-py support: bar / line / scatter")
    data = d["data"]
    L = [
        "import originpro as op",
        f"wks = op.new_sheet('w', 'data')",
        f"wks.from_file({json.dumps(str(data))})",
        "gp = op.new_graph()",
        "gl = gp[0]",
    ]
    if chart == "bar":
        L.append("plot = gl.add_plot(wks, 0, 1, type='column')")
        L.append("plot.colormap = [1]  # 0-based index; adjust to palette in UI")
    elif chart == "line":
        L.append("plot = gl.add_plot(wks, 0, 1, type='line')")
    else:
        L.append("plot = gl.add_plot(wks, 0, 1, type='scatter')")
    L += [
        "gl.rescale()",
        "gl.axis('x').fontsize = %d" % d["fontsize"],
        "gl.axis('y').fontsize = %d" % d["fontsize"],
        "gp.save_fig(%s, dpi=300)" % json.dumps(d["fig_out"]),
    ]
    return "\n".join(L) + "\n"


GENERATORS = {
    "ggplot2": gen_ggplot2,
    "seaborn": gen_seaborn,
    "matplotlib": gen_matplotlib,
    "origin": gen_origin,
}

FOREST_ID_ALIASES = ["sentinel_id", "SNP", "id", "locus", "rsid", "study"]
FOREST_EST_ALIASES = ["aligned_beta", "beta", "b", "logor", "log_OR", "effect", "logHR"]
FOREST_SE_ALIASES = ["aligned_se", "se", "std_error", "standard_error", "SE"]
FOREST_LO_ALIASES = ["lower", "ci_low", "lci", "or_lci95", "l95"]
FOREST_HI_ALIASES = ["upper", "ci_high", "uci", "or_uci95", "u95"]


def detect_forest_columns(path: Path) -> dict:
    cols = list(pd.read_csv(path, sep=None, engine="python", nrows=2).columns)

    def _pick(aliases):
        return next((c for c in aliases if c in cols), None)

    return {
        "groupcol": _pick(FOREST_ID_ALIASES) or "id",
        "ycol": _pick(FOREST_EST_ALIASES) or "est",
        "secol": _pick(FOREST_SE_ALIASES),
        "locol": _pick(FOREST_LO_ALIASES),
        "hicol": _pick(FOREST_HI_ALIASES),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--style", help="style id from catalog/styles.json")
    ap.add_argument("--chart", choices=["bar", "line", "scatter", "forest"], required=True)
    ap.add_argument("--target", choices=list(GENERATORS), required=True)
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--xcol", default="x")
    ap.add_argument("--ycol", default="y")
    ap.add_argument("--groupcol", default="group")
    ap.add_argument("--errorcol", default=None, help="SE column for bands/bars")
    ap.add_argument("--locol", default="lower")
    ap.add_argument("--hicol", default="upper")
    ap.add_argument("--palette", default=None, help="comma hex colors")
    ap.add_argument("--font", default="Arial")
    ap.add_argument("--fontsize", type=float, default=8.0)
    args = ap.parse_args()

    if args.palette:
        colors = [c.strip() for c in args.palette.split(",") if c.strip()]
    else:
        style = plot_utils.get_style(args.style)
        colors = plot_utils.okabe_ito() if style is None else plot_utils.okabe_ito()[:6]

    detect = {}
    if args.chart == "forest":
        detect = detect_forest_columns(args.data)
    xcol = args.xcol if args.xcol != "x" else detect.get("ycol") or "x"
    # for forest the "y" of the plot is the effect column; the row id is group
    ycol = args.ycol if args.ycol != "y" else "est"
    groupcol = args.groupcol if args.groupcol != "group" else detect.get("groupcol") or "group"
    locol = args.locol if args.locol != "lower" else detect.get("locol") or "lower"
    hicol = args.hicol if args.hicol != "upper" else detect.get("hicol") or "upper"
    forest_from_se = bool(detect.get("secol")) and not (detect.get("locol") or detect.get("hicol"))
    if args.chart == "forest":
        est_vals = pd.to_numeric(
            pd.read_csv(args.data, sep=None, engine="python", usecols=[detect["ycol"] or "est"])[
                detect["ycol"] or "est"
            ],
            errors="coerce",
        ).dropna()
        ref = 0.0 if est_vals.abs().max() < 1.0 else 1.0
    else:
        ref = 0.0

    out_path = Path(args.out)
    if out_path.suffix == "":
        ext = {"ggplot2": ".R", "seaborn": ".py", "matplotlib": ".py", "origin": ".py"}[args.target]
        out_path = out_path.with_suffix(ext)
    d = {
        "data": args.data,
        "out": out_path.name,
        "fig_out": out_path.with_suffix(".png").name,
        "xcol": xcol,
        "ycol": ycol,
        "groupcol": groupcol,
        "errorcol": args.errorcol,
        "locol": locol,
        "hicol": hicol,
        "forest_from_se": forest_from_se,
        "secol": detect.get("secol"),
        "ref": ref,
        "font": args.font,
        "fontsize": args.fontsize,
        "palette_py": _fmt_palette(colors),
    }
    code = GENERATORS[args.target](args.chart, d)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(code, encoding="utf-8")
    print(f"converted -> {out_path} (target={args.target}, chart={args.chart})")


if __name__ == "__main__":
    main()
