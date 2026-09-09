"""Shared helpers for the paper-plot-skills suite (v2).

Everything here is importable from any skill script:

    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "shared"))
    import plot_utils

Implemented:
* style catalog loading + natural-language search
* palette lookup (Okabe-Ito / ColorBrewer / viridis)
* colour-vision-deficiency simulation (Machado et al. 2009 matrices)
* confusable-pair detection + Okabe-Ito replacement suggestions
* significance stars
* journal rcParams builder (Nature / Cell / PLOS / ...)
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

SUITE_ROOT = Path(__file__).resolve().parent.parent
CATALOG_DIR = SUITE_ROOT / "catalog"

# Machado, Oliveira & Fernandes (2009) physiologically-inspired matrices
# for full (severity = 1.0) colour-vision deficiency.
_CVD_MATRICES = {
    "protan": [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ],
    "deutan": [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ],
    "tritan": [
        [1.255528, -0.076749, -0.178779],
        [-0.078411, 0.930809, 0.147602],
        [0.004733, 0.691367, 0.303900],
    ],
}


def _load_json(name: str) -> dict:
    with (CATALOG_DIR / name).open(encoding="utf-8") as fh:
        return json.load(fh)


def py_dumps(obj, indent: int = 2) -> str:
    """json.dumps but with Python literals (True/False/None), for codegen."""

    def _fmt(value, level: int) -> str:
        pad = " " * indent * level
        pad_inner = " " * indent * (level + 1)
        if isinstance(value, bool):
            return "True" if value else "False"
        if value is None:
            return "None"
        if isinstance(value, dict):
            if not value:
                return "{}"
            items = [
                f"{pad_inner}{json.dumps(k, ensure_ascii=False)}: {_fmt(v, level + 1)}"
                for k, v in value.items()
            ]
            return "{\n" + ",\n".join(items) + f"\n{pad}}}"
        if isinstance(value, (list, tuple)):
            if not value:
                return "[]"
            items = [_fmt(v, level + 1) for v in value]
            return "[\n" + ",\n".join(f"{pad_inner}{i}" for i in items) + f"\n{pad}]"
        if isinstance(value, str):
            return json.dumps(value, ensure_ascii=False)
        return repr(value)

    return _fmt(obj, 0)


# --------------------------------------------------------------------------- #
# Style catalog
# --------------------------------------------------------------------------- #
def load_styles() -> list[dict]:
    return _load_json("styles.json")["styles"]


def get_style(style_id: str) -> dict | None:
    for s in load_styles():
        if s["id"] == style_id:
            return s
    return None


def _tokens(text: str) -> list[str]:
    """English word tokens + lower-cased full string for CJK matching."""
    return re.findall(r"[a-z0-9]+", text.lower())


def search_styles(query: str, top_k: int = 5) -> list[dict]:
    """Rank styles by overlap with the natural-language query.

    Chinese queries are matched by substring against tags/aliases; English by
    word overlap. Returns the top-k entries annotated with a `_score`.
    """
    q = query.strip().lower()
    q_words = _tokens(q)
    scored: list[dict] = []
    for style in load_styles():
        hay_fields = {
            "name": style["name"],
            "id": style["id"],
            "figure_type": " ".join(style["figure_type"]),
            "journal_hint": " ".join(style["journal_hint"]),
            "discipline": " ".join(style["discipline"]),
            "palette": style["palette"],
            "tags": " ".join(style["tags"]),
            "aliases": " ".join(style["aliases"]),
        }
        hay = " ".join(hay_fields.values()).lower()
        score = 0.0
        # Chinese substring on the high-value fields
        for field, weight in (
            ("aliases", 3.0),
            ("tags", 2.0),
            ("name", 1.5),
            ("figure_type", 1.0),
            ("journal_hint", 1.0),
            ("discipline", 1.0),
            ("palette", 0.5),
        ):
            if re.search(r"[\u4e00-\u9fff]", q) and q in hay_fields[field].lower():
                score += weight
        # English word overlap
        for w in q_words:
            if len(w) < 2:
                continue
            score += 1.0 if w in hay else 0.0
            for alias in style["aliases"]:
                if w == alias.lower():
                    score += 2.0
        if score > 0 or not q_words and not re.search(r"[\u4e00-\u9fff]", q):
            entry = dict(style)
            entry["_score"] = round(score, 2)
            scored.append(entry)
    scored.sort(key=lambda s: s["_score"], reverse=True)
    return scored[:top_k]


# --------------------------------------------------------------------------- #
# Palettes
# --------------------------------------------------------------------------- #
def load_palettes() -> list[dict]:
    return _load_json("palettes.json")["palettes"]


def get_palette(palette_id: str) -> dict | None:
    for p in load_palettes():
        if p["id"] == palette_id.lower():
            return p
    return None


def okabe_ito() -> list[str]:
    p = get_palette("okabe-ito")
    return list(p["colors"])


# --------------------------------------------------------------------------- #
# Colour-vision-deficiency simulation
# --------------------------------------------------------------------------- #
def _hex_to_rgb01(hex_color: str) -> tuple[float, float, float]:
    h = hex_color.lstrip("#")
    if len(h) == 3:
        h = "".join(ch * 2 for ch in h)
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def _rgb01_to_hex(rgb: tuple[float, float, float]) -> str:
    vals = []
    for v in rgb:
        v = min(1.0, max(0.0, v))
        vals.append(f"{round(v * 255):02x}")
    return "#" + "".join(vals)


def _srgb_to_lab(hex_color: str) -> tuple[float, float, float]:
    """sRGB hex -> CIELAB (D65), used for a perceptual distance metric."""

    def _linear(c: float) -> float:
        if c <= 0.04045:
            return c / 12.92
        return ((c + 0.055) / 1.055) ** 2.4

    def _f(t: float) -> float:
        delta = 6.0 / 29.0
        if t > delta**3:
            return t ** (1.0 / 3.0)
        return t / (3.0 * delta**2) + 4.0 / 29.0

    r, g, b = (_linear(c) for c in _hex_to_rgb01(hex_color))
    x = 0.4124 * r + 0.3576 * g + 0.1805 * b
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = 0.0193 * r + 0.1192 * g + 0.9505 * b
    fx, fy, fz = _f(x / 0.95047), _f(y / 1.0), _f(z / 1.08883)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


def simulate_cvd(
    hex_color: str, kind: str = "deutan", severity: float = 1.0
) -> str:
    """Simulate a colour under protan/deutan/tritan vision."""
    rgb = list(_hex_to_rgb01(hex_color))
    rgb = [math.pow(c, 2.2) for c in rgb]  # gamma-expand
    matrix = _CVD_MATRICES[kind]
    # severity blends between identity and full deficiency
    blended = [
        severity * sum(row[i] * rgb[i] for i in range(3))
        + (1 - severity) * rgb[j]
        for j, row in enumerate(matrix)
    ]
    blended = [math.pow(max(0.0, c), 1.0 / 2.2) for c in blended]
    return _rgb01_to_hex(tuple(blended))


def _distance(hex_a: str, hex_b: str) -> float:
    """CIE76 ΔE between two hex colours (pass simulated colours in here)."""
    a = _srgb_to_lab(hex_a)
    b = _srgb_to_lab(hex_b)
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def colorblind_report(
    colors: list[str], threshold: float = 25.0, kinds=("deutan", "protan", "tritan")
) -> dict:
    """Find confusable pairs under CVD simulation and suggest Okabe-Ito swaps.

    Distance is CIE76 ΔE between the two *simulated* colours. ΔE < 20 is
    flagged "strong", ΔE in [20, threshold) "borderline". Suggestion logic
    prefers chromatic Okabe-Ito colours and never repeats a replacement.

    Returns:
        {
          "pairs": [{i, j, color_i, color_j, kind, distance}],
          "suggestions": [{index, original, replacement}],
          "min_distance": {...}
        }
    """
    safe = okabe_ito()
    pairs = []
    for kind in kinds:
        sim = [simulate_cvd(c, kind) for c in colors]
        for i in range(len(colors)):
            for j in range(i + 1, len(colors)):
                d = _distance(sim[i], sim[j])
                if d < threshold:
                    pairs.append(
                        {
                            "i": i,
                            "j": j,
                            "color_i": colors[i],
                            "color_j": colors[j],
                            "kind": kind,
                            "distance": round(d, 3),
                            "level": "strong" if d < 20.0 else "borderline",
                        }
                    )

    suggestions = []
    flagged = sorted({p["i"] for p in pairs} | {p["j"] for p in pairs})
    chromatic = [c for c in safe if c.lower() != "#000000"]
    assigned: set[str] = set()

    def _best_for(idx: int, allow_black: bool) -> tuple[str, float]:
        current = colors[idx]
        others = [c for c in colors if c != current]
        pool = chromatic if not allow_black else chromatic + ["#000000"]
        best, best_d = None, -1.0
        for cand in pool:
            if cand in assigned:
                continue
            d_min = min(
                (
                    _distance(simulate_cvd(cand, k), simulate_cvd(other, k))
                    for other in others
                    for k in ("deutan", "protan")
                ),
                default=1.0,
            )
            if d_min > best_d:
                best, best_d = cand, d_min
        return best, best_d

    for idx in flagged:
        cand, score = _best_for(idx, allow_black=False)
        if cand is None or score < 18.0:
            # not enough chromatic separation left -> black as last resort
            cand, score = _best_for(idx, allow_black=True)
        if cand is None:  # more flagged colours than palette entries
            for fallback in safe:
                if fallback not in assigned:
                    cand, score = fallback, 0.0
                    break
        assigned.add(cand)
        suggestions.append(
            {"index": idx, "original": colors[idx], "replacement": cand, "score": round(score, 3)}
        )

    return {"pairs": pairs, "suggestions": suggestions}


# --------------------------------------------------------------------------- #
# Stats
# --------------------------------------------------------------------------- #
def significance_stars(p: float) -> str:
    if p < 0.001:
        return "***"
    if p < 0.01:
        return "**"
    if p < 0.05:
        return "*"
    return "ns"


def bh_adjust(pvalues: list[float]) -> list[float]:
    """Benjamini-Hochberg FDR."""
    n = len(pvalues)
    if n == 0:
        return []
    order = sorted(range(n), key=lambda i: pvalues[i])
    out = [0.0] * n
    running = 1.0
    for rank, idx in enumerate(reversed(order), start=1):
        running = min(running, pvalues[idx] * n / (n - rank + 1))
        out[idx] = min(1.0, running)
    return out


# --------------------------------------------------------------------------- #
# Journal rcParams
# --------------------------------------------------------------------------- #
def load_journals() -> dict:
    return _load_json("journal_specs.json")["journals"]


def get_journal(journal_id: str) -> dict | None:
    return load_journals().get(journal_id)


def journal_rcparams(journal_id: str, font_scale: float = 1.0) -> dict:
    """Build a matplotlib rcParams dict for a journal entry.

    font_scale adapts the point size for large multi-panel canvases; the base
    size is the middle of the journal's accepted range.
    """
    spec = get_journal(journal_id)
    if spec is None:
        raise KeyError(f"unknown journal: {journal_id}")
    lo, hi = spec["font_size_pt"]["min"], spec["font_size_pt"]["max"]
    base = (lo + hi) / 2.0 * font_scale
    families = spec["font_family"]
    sans = [f for f in families if f not in ("sans-serif", "serif")]
    rc = {
        "font.size": base,
        "axes.labelsize": base,
        "axes.titlesize": base + 0.5,
        "xtick.labelsize": base - 0.5,
        "ytick.labelsize": base - 0.5,
        "legend.fontsize": base - 0.5,
        "axes.linewidth": (spec["line_width_pt"]["min"] + spec["line_width_pt"]["max"]) / 2.0,
        "figure.dpi": 100,
        "savefig.dpi": spec["dpi"]["recommended"],
        "savefig.format": "png",
        "axes.unicode_minus": False,
    }
    if "serif" in families and "sans-serif" not in families:
        rc["font.family"] = "serif"
        rc["font.serif"] = sans or ["Times New Roman", "DejaVu Serif"]
    else:
        rc["font.family"] = "sans-serif"
        rc["font.sans-serif"] = sans or ["Arial", "Helvetica", "DejaVu Sans"]
    return rc


def panel_size_mm(journal_id: str, double: bool = True) -> tuple[float, float]:
    spec = get_journal(journal_id)
    w = spec["panel_width_mm"]["double" if double else "single"]
    return w / 25.4, w / 25.4 * 0.78
