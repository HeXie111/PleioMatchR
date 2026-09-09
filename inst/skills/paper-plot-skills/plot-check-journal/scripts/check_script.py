#!/usr/bin/env python3
"""Submission figure compliance checker.

Examples:
    python check_script.py --script figure.py --journal nature --out report.md
    python check_script.py --image fig.png --journal cell --out report.md
    python check_script.py --script figure.py --journal nature --fix
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / "plot-batch-style" / "scripts"))
import plot_utils  # noqa: E402
from apply_rcparams import force_dpi, inject_rcparams  # noqa: E402


def _last(pattern: str, text: str) -> str | None:
    hits = re.findall(pattern, text, flags=re.M | re.S)
    return hits[-1] if hits else None


def inspect_script(text: str) -> dict:
    found: dict[str, str | None] = {}
    found["font_family"] = _last(
        r"""['"]font\.family['"]\s*:\s*['"]([^'"]+)['"]""", text
    )
    found["sans"] = _last(
        r"""['"]font\.sans-serif['"]\s*:\s*\[([^\]]*)\]""", text
    )
    found["font_size"] = _last(
        r"""['"]font\.size['"]\s*:\s*([0-9.]+)""", text
    )
    found["axes_linewidth"] = _last(
        r"""['"]axes\.linewidth['"]\s*:\s*([0-9.]+)""", text
    )
    found["savefig_dpi"] = _last(r"dpi\s*=\s*(\d+)", text)
    found["savefig_format"] = _last(r"""['"]savefig\.format['"]\s*:\s*['"]([^'"]+)""", text)
    ext = _last(r"savefig\(\s*['\"][^'\"]+\.([A-Za-z]+)['\"]", text)
    found["savefig_ext"] = ext
    found["usetex"] = _last(
        r"""['"]text\.usetex['"]\s*:\s*(True|False)""", text
    )
    return found


def _status(value: bool | None) -> str:
    if value is True:
        return "✓"
    if value is False:
        return "✗"
    return "⚠"


def build_rows_script(spec: dict, found: dict) -> list[dict]:
    rows = []
    lo, hi = spec["font_size_pt"]["min"], spec["font_size_pt"]["max"]
    size = float(found["font_size"]) if found["font_size"] else None
    if size is None:
        size_ok, size_note = None, "not set (matplotlib default = 10pt)"
    else:
        size_ok = lo <= size <= hi
        size_note = f"{size}pt (range {lo}-{hi}pt)"
    rows.append(
        {
            "parameter": "font size",
            "spec": f"{lo}-{hi} pt",
            "found": size_note,
            "status": _status(size_ok),
            "fix": f"set font.size = {round((lo+hi)/2,1)}",
        }
    )

    allowed = [f.lower() for f in spec["font_family"]]
    fam = (found["font_family"] or "").lower()
    sans_list = (found["sans"] or "").lower()
    if fam:
        if any(a in fam for a in allowed if "serif" not in a):
            fam_ok, fam_note = True, found["font_family"]
        elif fam in ("serif",) and "serif" in allowed:
            fam_ok, fam_note = True, found["font_family"]
        else:
            fam_ok, fam_note = False, found["font_family"]
    elif sans_list:
        fam_note = f"sans-serif = [{sans_list.strip()}]"
        fam_ok = any(a.replace("sans-serif", "") in sans_list for a in allowed if a)
    else:
        fam_ok, fam_note = None, "not set (matplotlib default DejaVu Sans)"
    rows.append(
        {
            "parameter": "font family",
            "spec": ", ".join(spec["font_family"]),
            "found": fam_note,
            "status": _status(fam_ok),
            "fix": "set font.family + font.sans-serif to the journal list",
        }
    )

    lw = float(found["axes_linewidth"]) if found["axes_linewidth"] else None
    lw_lo, lw_hi = spec["line_width_pt"]["min"], spec["line_width_pt"]["max"]
    if lw is None:
        lw_ok, lw_note = None, "not set (matplotlib default 0.8)"
    else:
        lw_ok, lw_note = lw_lo <= lw <= lw_hi, f"{lw}pt"
    rows.append(
        {
            "parameter": "axes line width",
            "spec": f"{lw_lo}-{lw_hi} pt",
            "found": lw_note,
            "status": _status(lw_ok),
            "fix": f"set axes.linewidth = {round((lw_lo+lw_hi)/2,2)}",
        }
    )

    dpi = int(found["savefig_dpi"]) if found["savefig_dpi"] else None
    dpi_min = spec["dpi"]["min"]
    if dpi is None:
        dpi_ok, dpi_note = False, "not set on savefig (default 100)"
    else:
        dpi_ok, dpi_note = dpi >= dpi_min, f"{dpi}"
    rows.append(
        {
            "parameter": "export dpi",
            "spec": f">= {dpi_min}",
            "found": dpi_note,
            "status": _status(dpi_ok),
            "fix": f"savefig(..., dpi={spec['dpi']['recommended']})",
        }
    )

    fmt = (found["savefig_format"] or found["savefig_ext"] or "png").lower()
    fmt_ok = fmt in [f.lower() for f in spec["formats"]]
    rows.append(
        {
            "parameter": "export format",
            "spec": ", ".join(spec["formats"]),
            "found": fmt,
            "status": _status(fmt_ok),
            "fix": f"choose one of {', '.join(spec['formats'])}",
        }
    )
    return rows


def build_rows_image(spec: dict, image_path: Path) -> tuple[list[dict], str]:
    img = Image.open(image_path)
    dpi = img.info.get("dpi", (72.0, 72.0))
    dpi_v = dpi[0]
    dpi_ok = dpi_v >= spec["dpi"]["min"]
    w_mm, h_mm = img.size[0] / dpi_v * 25.4, img.size[1] / dpi_v * 25.4
    rows = [
        {
            "parameter": "pixel size",
            "spec": ">= journal min dpi",
            "found": f"{img.size[0]}x{img.size[1]} px",
            "status": "✓",
            "fix": "-",
        },
        {
            "parameter": "dpi metadata",
            "spec": f">= {spec['dpi']['min']}",
            "found": f"{dpi_v:g}",
            "status": _status(dpi_ok),
            "fix": "re-export with the dpi from journal_rcparams()",
        },
        {
            "parameter": "physical size",
            "spec": f"double col ~{spec['panel_width_mm']['double']} mm wide",
            "found": f"{w_mm:.0f}x{h_mm:.0f} mm @ {dpi_v:g} dpi",
            "status": "✓" if w_mm <= spec["panel_width_mm"]["double"] * 1.05 else "✗",
            "fix": "widen or reduce figsize; keep font size in pt",
        },
        {
            "parameter": "font / line width",
            "spec": "script-only check",
            "found": "not detectable from raster",
            "status": "⚠",
            "fix": "run with --script on the generating code",
        },
    ]
    return rows, f"{img.format}"


def fix_code(journal_id: str) -> str:
    rc = plot_utils.journal_rcparams(journal_id)
    return (
        "plt.rcParams.update(\n"
        + plot_utils.py_dumps(rc)
        + "\n)"
    )


def render_report(
    title: str, journal_label: str, rows: list[dict], fix: str
) -> str:
    lines = [f"# Submission figure check — {journal_label}", "", f"Target: `{title}`", ""]
    lines.append("| parameter | journal spec | found | status | fix |")
    lines.append("|---|---|---|---|---|")
    for r in rows:
        lines.append(
            f"| {r['parameter']} | {r['spec']} | {r['found']} | {r['status']} | {r['fix']} |"
        )
    lines += ["", "## One-click fix (rcParams)", "", "```python", fix, "```"]
    lines += [
        "",
        "DPI / format: edit `savefig(..., dpi=..., format=...)`; for TIFF/SVG use the "
        "file extension. Re-run plot-batch-style when fixing several scripts.",
    ]
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--script", type=Path)
    src.add_argument("--image", type=Path)
    ap.add_argument("--journal", required=True)
    ap.add_argument("--out", type=Path, help="write report to markdown file")
    ap.add_argument("--fix", action="store_true", help="write a fixed script copy")
    args = ap.parse_args()

    spec = plot_utils.get_journal(args.journal)
    if spec is None:
        raise SystemExit(
            f"unknown journal {args.journal!r}; available: {', '.join(plot_utils.load_journals())}"
        )

    if args.image:
        rows, _ = build_rows_image(spec, args.image)
        report = render_report(str(args.image), spec["label"], rows, fix_code(args.journal))
    else:
        text = args.script.read_text(encoding="utf-8")
        found = inspect_script(text)
        rows = build_rows_script(spec, found)
        report = render_report(str(args.script), spec["label"], rows, fix_code(args.journal))
        if args.fix:
            rc = plot_utils.journal_rcparams(args.journal)
            patched, _ = inject_rcparams(text, rc)
            patched = force_dpi(patched, rc["savefig.dpi"])
            dest = args.script.with_name(args.script.stem + "_fixed.py")
            dest.write_text(patched, encoding="utf-8")
            print(f"fixed script written to {dest}")

    if args.out:
        args.out.write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
