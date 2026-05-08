"""Render the geo_cslc_s1 runconfig template by substituting placeholders.

The template (`fixtures/geo_cslc_s1_template.yaml`) carries three sentinels
inherited from COMPASS's own test template:

    @DATA_PATH@   path to Zenodo fixtures (typically /data inside the container)
    @TEST_PATH@   path that will hold product/ and scratch/ (typically /logs/work)
    @BURST_ID@    burst identifier (default t064_135523_iw2)

This module is a deliberately dumb string replacer — it does not re-parse the
YAML, so quoting and indentation in the template are preserved verbatim.

Example:
    python -m tools.render_runconfig \\
        --template /workspace/fixtures/geo_cslc_s1_template.yaml \\
        --output /logs/runconfig.yaml \\
        --data-path /data \\
        --test-path /logs/work \\
        --burst-id t064_135523_iw2
"""
from __future__ import annotations

import argparse
import os
import sys


def render(template_path: str, output_path: str, data_path: str,
           test_path: str, burst_id: str) -> None:
    """Render the template and write the result to ``output_path``.

    Args:
        template_path: Absolute path to the input template.
        output_path: Absolute path for the rendered runconfig.
        data_path: Value substituted for ``@DATA_PATH@``.
        test_path: Value substituted for ``@TEST_PATH@``. Subdirectories
            ``product/`` and ``scratch/`` are created underneath.
        burst_id: Value substituted for ``@BURST_ID@``.

    Raises:
        FileNotFoundError: If the template does not exist.
    """
    with open(template_path, "r", encoding="utf-8") as f:
        text = f.read()

    rendered = (
        text
        .replace("@DATA_PATH@", data_path)
        .replace("@TEST_PATH@", test_path)
        .replace("@BURST_ID@", burst_id)
    )

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    # Pre-create COMPASS's expected output subdirectories so that downstream
    # tools do not hit "directory does not exist" errors during the run.
    os.makedirs(os.path.join(test_path, "product"), exist_ok=True)
    os.makedirs(os.path.join(test_path, "scratch"), exist_ok=True)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(rendered)

    print(f"[render_runconfig] wrote {output_path}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True,
                        help="Path to the template YAML")
    parser.add_argument("--output", required=True,
                        help="Path for the rendered runconfig")
    parser.add_argument("--data-path", required=True,
                        help="Value substituted for @DATA_PATH@")
    parser.add_argument("--test-path", required=True,
                        help="Value substituted for @TEST_PATH@ (parent of product/ and scratch/)")
    parser.add_argument("--burst-id", default="t064_135523_iw2",
                        help="Value substituted for @BURST_ID@")
    args = parser.parse_args(argv)

    render(
        template_path=args.template,
        output_path=args.output,
        data_path=args.data_path,
        test_path=args.test_path,
        burst_id=args.burst_id,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
