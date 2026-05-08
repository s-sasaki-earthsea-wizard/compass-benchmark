# Baseline: SAFE → CSLC E2E (no profiler)

> This report is **hand-transcribed** from `scripts/run_baseline.sh` artifacts
> in `logs_baseline_*/`. Strip machine-specific tokens (absolute paths,
> hostnames) during transcription.

## TL;DR

(filled after Phase 2)

## Methodology

- Harness: [`run_baseline.sh`](../scripts/run_baseline.sh)
- Image: `compass-benchmark:latest` (FROM `opera/cslc_s1:final_0.5.6`)
- Runconfig: rendered from
  [`fixtures/geo_cslc_s1_template.yaml`](../fixtures/geo_cslc_s1_template.yaml)
  by `tools/render_runconfig.py`
- Input dataset: [Zenodo 7668411](https://zenodo.org/record/7668411)
  - SAFE: `S1A_IW_SLC__1SDV_20221016T015043_..._6681.zip`
  - burst ID: `t064_135523_iw2`, date: `20221016`
- Measurement: `/usr/bin/time -v` inside the container
- OOM safety net: `ULIMIT_FRACTION=80` (virtual memory capped at 80% of physical RAM)

## Results

| Metric | Value |
|---|---:|
| Inner wall (`s1_cslc.py` only) | TBD |
| Outer wall (incl. `docker compose run` startup) | TBD |
| Max RSS | TBD |
| Output h5 size | TBD |
| Output VV shape | TBD |

## Findings

(filled after Phase 2)

## Output verification

Result of `tools/verify_output.py`.

| Field | Value |
|---|---|
| ok | TBD |
| size_mb | TBD |
| vv_shape | TBD |
| vv_dtype | TBD |
| vv_nonzero_ratio | TBD |
