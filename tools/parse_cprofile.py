"""Reduce a cProfile pstats dump to a markdown summary table.

Output is intended as raw input for hand-transcription into
`reports/report_profile_cprofile.md` (the canonical record). Absolute paths
inside function names are partially redacted so the markdown is less
machine-specific, but final transcription should still strip any remaining
host-specific tokens.

Example:
    python -m tools.parse_cprofile \\
        --input /logs/cprofile.prof \\
        --output /logs/cprofile_summary.md \\
        --top 30 \\
        --sort cumulative
"""
from __future__ import annotations

import argparse
import io
import os
import pstats
import re
import sys


def _strip_host_paths(line: str) -> str:
    """Shorten absolute paths to keep host-specific tokens out of the report.

    Examples:
        ``/home/compass_user/miniforge3/envs/COMPASS/lib/python3.11/site-packages/foo/bar.py:42``
        becomes ``site-packages/foo/bar.py:42``.
    """
    line = re.sub(r"/[^ ]*?/site-packages/", "site-packages/", line)
    line = re.sub(r"/home/[^/]+/", "~/", line)
    return line


def summarize(prof_path: str, top_n: int, sort_key: str) -> str:
    """Format a pstats dump as markdown.

    Args:
        prof_path: Path to the .prof file produced by cProfile.
        top_n: Number of rows to include from the top of the sorted output.
        sort_key: pstats SortKey name (e.g. ``cumulative``, ``tottime``,
            ``ncalls``).

    Returns:
        Markdown text suitable for writing to disk.
    """
    buf = io.StringIO()
    stats = pstats.Stats(prof_path, stream=buf)
    # Avoid pstats.strip_dirs() — it drops information we want to retain
    # (parent paths help disambiguate same-named functions across modules).
    stats.strip_dirs = lambda: stats
    stats.sort_stats(sort_key)
    stats.print_stats(top_n)
    raw = buf.getvalue()

    out: list[str] = []
    out.append(f"# cProfile summary: `{os.path.basename(prof_path)}`")
    out.append("")
    out.append(f"- sort key: `{sort_key}`")
    out.append(f"- top N: {top_n}")
    out.append(f"- total stats: {stats.total_calls} calls, {stats.total_tt:.3f}s")
    out.append("")
    out.append("```")
    for line in raw.splitlines():
        out.append(_strip_host_paths(line))
    out.append("```")
    return "\n".join(out) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Path to the .prof file")
    parser.add_argument("--output", required=True, help="Path for the output markdown")
    parser.add_argument("--top", type=int, default=30, help="Number of rows to include")
    parser.add_argument("--sort", default="cumulative",
                        help="Sort key (cumulative / tottime / ncalls / ...)")
    args = parser.parse_args(argv)

    md = summarize(args.input, args.top, args.sort)
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(md)
    print(f"[parse_cprofile] wrote {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
