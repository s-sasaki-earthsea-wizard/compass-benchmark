# Profile: SAFE → CSLC E2E (cProfile, deterministic)

> This report is **hand-transcribed** from `scripts/run_profile_cprofile.sh`
> artifacts in `logs_cprofile_*/`. The raw pstats dump lives at
> `logs_cprofile_*/cprofile.prof`; markdown views are emitted to
> `cprofile_summary.md` (sorted by cumulative time) and `cprofile_tottime.md`
> (sorted by self time). `tools/parse_cprofile.py` partially redacts host
> paths, but transcription should still strip any remaining machine-specific
> tokens.

## TL;DR

(filled after Phase 3-4)

## Methodology

- Harness: [`run_profile_cprofile.sh`](../scripts/run_profile_cprofile.sh)
- Profiler: stdlib `cProfile`
  - Launch: `python -m cProfile -o /logs/cprofile.prof $(which s1_cslc.py) --grid geo /logs/runconfig.yaml`
  - Reduction: [`tools/parse_cprofile.py`](../tools/parse_cprofile.py)
- Note: cProfile carries 10-30% overhead vs. an unprofiled run. Use
  [report_baseline.md](report_baseline.md) for clean wall-time numbers.

## Results

### Top by cumulative time

| Function | ncalls | tottime | cumtime | per-call |
|---|--:|--:|--:|--:|
| TBD | | | | |

### Top by tottime (self time)

| Function | ncalls | tottime | per-call |
|---|--:|--:|--:|
| TBD | | | |

## Findings

(filled after Phase 4)

## Cross-check vs. py-spy

Compare against [report_profile_pyspy.md](report_profile_pyspy.md): the same
hot regions should surface in both the sampling and deterministic runs.
