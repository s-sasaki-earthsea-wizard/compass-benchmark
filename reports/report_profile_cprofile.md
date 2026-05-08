# Profile: SAFE → CSLC E2E (cProfile, deterministic)

> This report is **hand-transcribed** from `scripts/run_profile_cprofile.sh`
> artifacts in `logs_cprofile_*/`. The raw pstats dump lives at
> `logs_cprofile_*/cprofile.prof`; markdown views are emitted to
> `cprofile_summary.md` (sorted by cumulative time) and `cprofile_tottime.md`
> (sorted by self time). `tools/parse_cprofile.py` partially redacts host
> paths, but transcription should still strip any remaining machine-specific
> tokens.

## TL;DR

cProfile reports **56.157 s** of profiled wall time across **3,501,880
function calls** for the same burst as the baseline run. The two heaviest
self-time entries are the ISCE3 C++ geocoder (`isce3.ext.isce3.geocode._geocode_slc`,
20.501 s) and h5py's `write_direct` (14.411 s, 3 calls). Inner wall
(`/usr/bin/time -v`) is **58.21 s** — only ~7 % over the 54.28 s baseline,
because the dominant cost is in compiled C/C++ that cProfile cannot
slow down.

## Methodology

- Harness: [`run_profile_cprofile.sh`](../scripts/run_profile_cprofile.sh)
- Profiler: stdlib `cProfile`
  - Launch: `python -m cProfile -o /logs/cprofile.prof $(command -v s1_cslc.py) --grid geo /logs/runconfig.yaml`
  - Reduction: [`tools/parse_cprofile.py`](../tools/parse_cprofile.py)
- Note: cProfile's nominal 10–30 % overhead is mostly absorbed by the C/C++
  hot path here. Use [report_baseline.md](report_baseline.md) for clean
  wall-time numbers.
- Run timestamp: 2026-05-08

## Results

### Top-level timings

| Metric | Value |
|---|---:|
| Profiled wall (cProfile total) | 56.157 s |
| Inner wall (`/usr/bin/time -v`) | 58.21 s |
| Outer wall (incl. compose startup) | 60 s |
| User CPU time | 257.22 s |
| System CPU time | 4.00 s |
| CPU utilization | 448 % |
| Max RSS | 6,204,524 KB (≈ 5.92 GiB) |
| Function calls | 3,501,880 (3,437,219 primitive) |

### Top by cumulative time

| Function | ncalls | tottime | cumtime | per-call |
|---|--:|--:|--:|--:|
| `isce3/geocode/geocode_slc.py:112(geocode_slc)` | 1 | 0.000 | 20.501 | 20.501 |
| `{built-in method isce3.ext.isce3.geocode._geocode_slc}` | 1 | 20.501 | 20.501 | 20.501 |
| `h5py/_hl/dataset.py:1070(write_direct)` | 3 | 14.411 | 14.411 | 4.804 |
| `matplotlib/font_manager.py:1112(addfont)` | 98 | 0.001 | 12.419 | 0.127 |
| `matplotlib/font_manager.py:340(ttfFontProperty)` | 38 | 0.002 | 12.127 | 0.319 |
| `compass/utils/browse_image.py:175(make_browse_image)` | 1 | 0.007 | 4.654 | 4.654 |
| `osgeo/gdal.py:1130(Warp)` | 1 | 0.000 | 4.574 | 4.574 |
| `{built-in method osgeo._gdal.wrapper_GDALWarpDestName}` | 1 | 4.559 | 4.559 | 4.559 |
| `compass/s1_cslc_qa.py:75(compute_CSLC_raster_stats)` | 1 | 0.001 | 4.375 | 4.375 |
| `compass/s1_geocode_slc.py:37(_wrap_phase)` | 2 | 3.777 | 3.777 | 1.889 |

### Top by tottime (self time)

| Function | ncalls | tottime | per-call |
|---|--:|--:|--:|
| `{built-in method isce3.ext.isce3.geocode._geocode_slc}` | 1 | 20.501 | 20.501 |
| `h5py/_hl/dataset.py:1070(write_direct)` | 3 | 14.411 | 4.804 |
| `{built-in method osgeo._gdal.wrapper_GDALWarpDestName}` | 1 | 4.559 | 4.559 |
| `compass/s1_geocode_slc.py:37(_wrap_phase)` | 2 | 3.777 | 1.889 |
| `h5py/_hl/dataset.py:1045(read_direct)` | 1 | 2.114 | 2.114 |
| `h5py/_hl/dataset.py:786(__getitem__)` | 12 | 1.917 | 0.160 |
| `numpy/lib/function_base.py:1606(angle)` | 1 | 1.300 | 1.300 |
| `{built-in method osgeo._gdal_array.BandRasterIONumPy}` | 24 | 1.036 | 0.043 |
| `h5py/_hl/files.py:620(close)` | 3 | 0.935 | 0.312 |
| `{built-in method posix.open}` | 5 | 0.590 | 0.118 |

## Findings

- ISCE3 geocoding (`_geocode_slc` C++ extension) dominates self time at
  20.5 s ≈ **36 %** of the 56.16 s profiled wall.
- h5py raw write (`write_direct`, 3 calls) is the next-largest single hot
  spot at 14.4 s ≈ **26 %** of profiled wall.
- Together, ISCE3 geocode + h5py write account for ≈ **62 %** of profiled
  wall in just two leaf entries.
- Matplotlib font discovery (`font_manager.addfont` + `ttfFontProperty`)
  contributes ~12 s of cumulative time — driven by import-time work, not
  per-burst processing. This is a one-time cost.
- `compass.s1_geocode_slc._wrap_phase` (Python-level numpy work) is the
  largest **self-time** entry that lives in pure Python (3.78 s).

## Cross-check vs. py-spy

The companion py-spy run is recorded in [report_profile_pyspy.md](report_profile_pyspy.md).
Cross-checking is **not possible** for this session: the py-spy traced
workload crashed before completion, so the flamegraph covers only the
pre-crash portion of the run. See that report for details.
