"""Parse a py-spy (inferno) flamegraph SVG into a hot-spot summary.

Each frame in the SVG is a ``<g>`` containing a ``<title>`` of the form
``"function (S samples, P%)"`` and a ``<rect>`` whose ``x``, ``y``, ``width``
encode the position in the flamegraph. ``y`` is the inverted stack depth
(top-of-stack near the bottom of the SVG; py-spy emits ``inverted=true``).

This script extracts every frame, prints:
  1. Top-N rectangles by inclusive samples (= time-on-stack incl. callees).
  2. Top-N function names by SUM of inclusive samples across all stack
     contexts (a function called from multiple call sites is aggregated).
  3. Presence/absence of a fixed list of Block 2 functions, used to verify
     AC2 of compass-benchmark issue #2 (QA/browse stage captured in
     flamegraph).

Output is plain text intended for hand-transcription into
``reports/report_profile_pyspy.md`` (the canonical record).

Example:
    python -m tools.parse_pyspy \\
        --input /logs/pyspy.svg \\
        --top 40
"""
from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from typing import Iterable

SVG_NS = "{http://www.w3.org/2000/svg}"

# Functions written by Block 2 of compass.s1_geocode_slc.run (QA / browse /
# stats / metadata). Verifying their presence in the flamegraph closes
# AC2 of compass-benchmark issue #2.
BLOCK2_FUNCTIONS = (
    "make_browse_image",
    "compute_CSLC_raster_stats",
    "percent_land_and_valid_pixels",
    "compute_correction_stats",
    "populate_rfi_dict",
    "set_orbit_type",
)


def _strip_unit(value: str) -> float:
    """Parse an SVG length attribute that may carry a ``%`` or ``px`` unit.

    Returns 0.0 on parse failure rather than raising — these coordinates are
    only used for hint output, not for correctness.
    """
    s = (value or "").strip().rstrip("%").rstrip("px")
    try:
        return float(s)
    except ValueError:
        return 0.0


def _find_frames_group(root: ET.Element) -> ET.Element:
    """Return the frames container from a py-spy SVG.

    The inferno flamegraph format used by py-spy nests the frames inside a
    second ``<svg id="frames">`` element (not a ``<g>``) carrying a
    ``total_samples`` attribute.
    """
    for el in root.iter():
        if el.get("id") == "frames":
            return el
    raise RuntimeError("frames container not found in SVG")


def parse_svg(svg_path: str) -> tuple[int, list[dict]]:
    """Extract every frame from a py-spy flamegraph SVG.

    Args:
        svg_path: Path to the ``pyspy.svg`` produced by ``py-spy record``.

    Returns:
        A tuple ``(total_samples, frames)`` where ``frames`` is a list of
        dicts with keys ``func``, ``samples``, ``pct``, ``x``, ``y``,
        ``width``.
    """
    tree = ET.parse(svg_path)
    root = tree.getroot()
    frames_group = _find_frames_group(root)
    total_samples = int(frames_group.get("total_samples", 0))

    title_re = re.compile(r"^(.*) \(([\d,]+) samples?, ([\d.]+)%\)$")
    frames: list[dict] = []
    for g in frames_group.findall(f"{SVG_NS}g"):
        title_el = g.find(f"{SVG_NS}title")
        rect_el = g.find(f"{SVG_NS}rect")
        if title_el is None or rect_el is None or title_el.text is None:
            continue
        m = title_re.match(title_el.text.strip())
        if not m:
            continue
        func, samples_s, pct_s = m.groups()
        frames.append({
            "func": func,
            "samples": int(samples_s.replace(",", "")),
            "pct": float(pct_s),
            "x": _strip_unit(rect_el.get("x", "0")),
            "y": _strip_unit(rect_el.get("y", "0")),
            "width": _strip_unit(rect_el.get("width", "0")),
        })
    return total_samples, frames


def _format_top_rects(frames: list[dict], top_n: int) -> str:
    """Format the top-N rectangles by inclusive samples."""
    rows = sorted(frames, key=lambda r: -r["samples"])[:top_n]
    out = [f"# Top {top_n} rectangles by inclusive samples (with stack y-position)"]
    out.append(f"{'samples':>8} {'pct':>7}  {'y':>6}  function")
    for r in rows:
        out.append(f"{r['samples']:>8} {r['pct']:>6.2f}%  {r['y']:>6.1f}  {r['func']}")
    return "\n".join(out)


def _format_top_funcs(frames: list[dict], total: int, top_n: int) -> str:
    """Format the top-N functions by SUM of inclusive samples.

    Useful when a function is called from many call sites — the per-rect
    view splits it across rows, but the per-function view aggregates.
    """
    by_func: dict[str, int] = defaultdict(int)
    for r in frames:
        by_func[r["func"]] += r["samples"]
    rows = sorted(by_func.items(), key=lambda kv: -kv[1])[:top_n]
    out = [f"# Top {top_n} functions by SUMMED inclusive samples"]
    out.append(f"{'samples':>8} {'pct':>7}  function")
    for func, s in rows:
        pct = 100.0 * s / total if total else 0.0
        out.append(f"{s:>8} {pct:>6.2f}%  {func}")
    return "\n".join(out)


def _format_block2_check(frames: list[dict], total: int,
                        targets: Iterable[str]) -> str:
    """Format the AC2 presence check for Block 2 functions."""
    out = ["# AC2 verification: presence of Block 2 functions"]
    for name in targets:
        matches = [r for r in frames if name in r["func"]]
        if not matches:
            out.append(f"  MISS   {name}")
            continue
        s = sum(r["samples"] for r in matches)
        pct = 100.0 * s / total if total else 0.0
        out.append(
            f"  FOUND  {name:36s} -> {s:>5} samples ({pct:5.2f}%) "
            f"across {len(matches)} rect(s)"
        )
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Path to pyspy.svg")
    parser.add_argument("--top", type=int, default=40,
                        help="Number of rows to show in each table")
    args = parser.parse_args(argv)

    total, frames = parse_svg(args.input)
    print(f"# total samples: {total}")
    print(f"# total frames:  {len(frames)}")
    print()
    print(_format_top_rects(frames, args.top))
    print()
    print(_format_top_funcs(frames, total, args.top))
    print()
    print(_format_block2_check(frames, total, BLOCK2_FUNCTIONS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
