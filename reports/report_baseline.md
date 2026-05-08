# Baseline: SAFE → CSLC E2E (no profiler)

> This report is **hand-transcribed** from `scripts/run_baseline.sh` artifacts
> in `logs_baseline_*/`. Strip machine-specific tokens (absolute paths,
> hostnames) during transcription.

## TL;DR

A single SAFE → CSLC run for burst `t064_135523_iw2` (date `20221016`)
completes in **54.28 s** of inner wall time, peaks at **5.89 GiB Max RSS**,
and produces a 259 MB CSLC HDF5 with a `(4420, 20210)` complex64 `VV`
raster. `verify_output.py` reports `ok=True`.

## Methodology

- Harness: [`run_baseline.sh`](../scripts/run_baseline.sh)
- Image: `compass-benchmark:latest` (FROM `opera/cslc_s1:final_0.5.6`)
- Runconfig: rendered from
  [`fixtures/geo_cslc_s1_template.yaml`](../fixtures/geo_cslc_s1_template.yaml)
  by `tools/render_runconfig.py`
- Input dataset: [Zenodo 7668411](https://zenodo.org/record/7668411)
  - SAFE: `S1A_IW_SLC__1SDV_20221016T015043_..._6681.zip`
  - burst ID: `t064_135523_iw2`, date: `20221016`
- Measurement: `/usr/bin/time -v` inside the container (wraps `s1_cslc.py`
  directly; rusage reflects the workload process)
- OOM safety net: `ULIMIT_FRACTION=80` (virtual memory capped at 80% of physical RAM)
- Run timestamp: 2026-05-08
- Host: 16-thread x86_64, 93 GiB RAM, Linux 6.17

## Results

| Metric | Value |
|---|---:|
| Inner wall (`s1_cslc.py` only) | 54.28 s |
| Outer wall (incl. `docker compose run` startup) | 56 s |
| User CPU time | 253.85 s |
| System CPU time | 4.07 s |
| CPU utilization | 475 % |
| Max RSS | 6,175,112 KB (≈ 5.89 GiB) |
| Minor page faults | 1,726,270 |
| Output h5 size | 259.33 MB |
| Output VV shape | (4420, 20210) |

## Findings

- The workload is **CPU-parallel**: 475 % CPU on a 54 s wall ≈ 4.75 cores
  active on average across 16 threads. User CPU (253.85 s) ≈ 4.7 × wall.
- Memory headroom is comfortable on this host (5.89 GiB peak vs. 93 GiB
  physical). The `ULIMIT_FRACTION=80` safety net was never approached.
- No major page faults; 1.7 M minor page faults are consistent with normal
  anonymous allocation under a 5.89 GiB heap.
- Exit status 0 with no stderr stack traces beyond benign GDAL
  `SetSpatialRef()` warnings against HDF5-backed datasets.

## Output verification

Result of `tools/verify_output.py` against
`work/product/t064_135523_iw2/20221016/t064_135523_iw2_20221016.h5`.

| Field | Value |
|---|---|
| ok | True |
| errors | [] |
| size_mb | 259.33 |
| vv_shape | (4420, 20210) |
| vv_dtype | complex64 |
| vv_nonzero_ratio | 1.0 |
