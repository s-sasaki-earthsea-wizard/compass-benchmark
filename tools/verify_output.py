"""Sanity-check the CSLC HDF5 produced by an end-to-end run.

This satisfies the completion requirement that the Zenodo 7668411 fixture
actually flows through the full SAFE -> CSLC pipeline. Checks:

- the file exists and is not absurdly small
- the expected data group (default ``/data``) and ``VV`` raster are present
- the ``VV`` raster has nonzero shape and a non-trivial fraction of nonzero
  pixels in a center sample (full-array scans would be wasteful)

Example:
    python -m tools.verify_output \\
        --hdf5 /logs/work/product/t064_135523_iw2/20221016/t064_135523_iw2_20221016.h5
"""
from __future__ import annotations

import argparse
import os
import sys

import h5py
import numpy as np


# Mirrors compass.utils.h5_helpers.DATA_PATH (expected to be '/data'). Inlined
# here so the bench harness stays self-contained and does not import compass
# at verification time.
DEFAULT_DATA_GROUP = "/data"


def verify(hdf5_path: str, data_group: str) -> dict:
    """Run sanity checks on the CSLC h5 file and return a summary dict.

    Args:
        hdf5_path: Path to the CSLC h5 produced by the run.
        data_group: HDF5 group expected to contain the rasters.

    Returns:
        A dict with keys: ``ok`` (bool), ``errors`` (list[str]), ``size_mb``,
        ``vv_shape``, ``vv_dtype``, ``vv_nonzero_ratio``.
    """
    errors: list[str] = []
    out: dict = {
        "ok": False,
        "errors": errors,
        "size_mb": 0.0,
        "vv_shape": None,
        "vv_dtype": None,
        "vv_nonzero_ratio": None,
    }

    if not os.path.exists(hdf5_path):
        errors.append(f"file not found: {hdf5_path}")
        return out

    size_bytes = os.path.getsize(hdf5_path)
    out["size_mb"] = size_bytes / (1024 * 1024)
    if size_bytes < 1024 * 1024:  # under 1MB is suspicious for a CSLC product
        errors.append(f"file too small: {size_bytes} bytes")

    try:
        with h5py.File(hdf5_path, "r") as h:
            if data_group not in h:
                errors.append(f"group missing: {data_group}")
            else:
                grp = h[data_group]
                if "VV" not in grp:
                    errors.append(f"VV dataset missing under {data_group}")
                else:
                    vv = grp["VV"]
                    out["vv_shape"] = tuple(vv.shape)
                    out["vv_dtype"] = str(vv.dtype)
                    if vv.size == 0:
                        errors.append("VV dataset is empty")
                    else:
                        # Sample a center window only — full-array scans on
                        # CSLC products are wasteful and unnecessary for a
                        # smoke check.
                        ny, nx = vv.shape[:2]
                        cy, cx = ny // 2, nx // 2
                        win = 256
                        y0 = max(0, cy - win); y1 = min(ny, cy + win)
                        x0 = max(0, cx - win); x1 = min(nx, cx + win)
                        sample = vv[y0:y1, x0:x1]
                        # complex64 is the typical CSLC dtype; take magnitude.
                        mag = np.abs(sample) if np.iscomplexobj(sample) else np.asarray(sample)
                        nonzero = float((mag > 0).sum() / mag.size) if mag.size else 0.0
                        out["vv_nonzero_ratio"] = nonzero
                        if nonzero < 0.01:
                            errors.append(
                                f"VV center sample mostly zero (nonzero ratio={nonzero:.4f})"
                            )
    except OSError as e:
        errors.append(f"h5py open failed: {e}")
    except Exception as e:  # noqa: BLE001
        errors.append(f"unexpected error during verify: {e!r}")

    out["ok"] = len(errors) == 0
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hdf5", required=True, help="Path to the CSLC h5 file")
    parser.add_argument("--data-group", default=DEFAULT_DATA_GROUP,
                        help=f"HDF5 group containing rasters (default: {DEFAULT_DATA_GROUP})")
    args = parser.parse_args(argv)

    result = verify(args.hdf5, args.data_group)
    print("[verify_output] result:")
    for k, v in result.items():
        print(f"  {k}: {v}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
