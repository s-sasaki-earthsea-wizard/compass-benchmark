# Profile: SAFE → CSLC E2E (py-spy flamegraph)

> This report is **hand-transcribed** from `scripts/run_profile_pyspy.sh`
> artifacts in `logs_pyspy_*/`. The flamegraph SVG is at `logs_pyspy_*/pyspy.svg`.
> Strip machine-specific tokens (absolute paths, hostnames) during transcription.

## TL;DR

(filled after Phase 3-4)

## Methodology

- Harness: [`run_profile_pyspy.sh`](../scripts/run_profile_pyspy.sh)
- Sampler: py-spy
  - `--rate 100` (100 Hz)
  - `--idle` (count sleeping threads as well, surfacing I/O waits)
  - `--subprocesses` (follow ISCE3 helper subprocesses if any)
  - `--format flamegraph`
- ptrace: container has `cap_add: SYS_PTRACE` and `seccomp=unconfined`
- Runconfig: same as the baseline run

## Results

### Top-level timings

| Metric | Value |
|---|---:|
| Wall (incl. py-spy overhead) | TBD |
| Sample count | TBD |
| Sampler errors | TBD |

### Region breakdown (inclusive samples)

Pulled from the `<title>` annotations in the flamegraph SVG.

| Region (Python frame) | Samples | % of wall | Approx. time |
|---|--:|--:|--:|
| TBD | | | |

## Findings

(filled after Phase 4)

## Per-step deep dives (as needed)

If any single step dominates the E2E wall, follow-up flamegraphs targeting
that step are recorded here.
