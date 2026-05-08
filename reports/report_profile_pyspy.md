# Profile: SAFE → CSLC E2E (py-spy flamegraph)

> This report is **hand-transcribed** from `scripts/run_profile_pyspy.sh`
> artifacts in `logs_pyspy_*/`. The flamegraph SVG is at `logs_pyspy_*/pyspy.svg`.
> Strip machine-specific tokens (absolute paths, hostnames) during transcription.

## TL;DR

py-spy itself ran to completion (exit 0) on this host and emitted a 132 KB
flamegraph from **4,714 samples** with **0 sampler errors**. However, the
**traced `s1_cslc.py` workload crashed before completing** with an h5py
error at file-close time (errno 103, `Software caused connection abort`),
in *both* attempted runs. The same workload, run **without** py-spy
attached (see [report_baseline.md](report_baseline.md)) and **with**
cProfile (see [report_profile_cprofile.md](report_profile_cprofile.md)),
completes cleanly. Root-cause investigation is **out of scope** for this
session; this report records only what was observed.

## Methodology

- Harness: [`run_profile_pyspy.sh`](../scripts/run_profile_pyspy.sh)
- Sampler: py-spy 0.4.2
  - `--rate 100` (100 Hz)
  - `--idle` (count sleeping threads as well, surfacing I/O waits)
  - `--subprocesses` (follow ISCE3 helper subprocesses if any)
  - `--format flamegraph`
- ptrace: container has `cap_add: SYS_PTRACE` and `seccomp=unconfined`,
  and the py-spy binary carries `cap_sys_ptrace+eip` file capability so
  the non-root `compass_user` can attach.
- Runconfig: same as the baseline run (burst `t064_135523_iw2`, 2022-10-16)
- Run timestamp: 2026-05-08 (two attempts: 23:16 and 23:21 JST)

## Results

### Top-level timings

| Metric | Run 1 | Run 2 |
|---|--:|--:|
| Outer wall (incl. compose startup) | 47 s | 48 s |
| Inner wall (`/usr/bin/time -v` on `py-spy record`) | 45.85 s | 45.90 s |
| Sample count | 4,615 | 4,714 |
| Sampler errors | 0 | 0 |
| `py-spy record` exit code | 0 | 0 |
| Traced `s1_cslc.py` exit | crashed (Traceback) | crashed (Traceback) |

`Max RSS` from `/usr/bin/time` (9,760 KB, run 2) reflects only the
**py-spy launcher process**, not the traced child — `/usr/bin/time -v`
in the current harness wraps `py-spy record`, and rusage is not
propagated from the traced child. The actual workload RSS for a
clean run is in [report_baseline.md](report_baseline.md).

### Traced-workload failure

Both attempts terminated with the same Python traceback:

```
File "compass/s1_geocode_slc.py", line 121, in run
    with h5py.File(output_hdf5, 'w') as geo_burst_h5:
  ...
  File "h5py/_hl/files.py", line 630, in close
    self.id._close_open_objects(h5f.OBJ_LOCAL | h5f.OBJ_FILE)
  ...
RuntimeError: Can't decrement id ref count
  (unable to close file, errno = 103,
   error message = 'Software caused connection abort')
```

The crash point is `h5py.File.close` exiting the `with` block in
`s1_geocode_slc.run`, after the geocode/topo phase logs already showed
completion of the first DEM block and PYSOLID Earth-tides computation
for the same burst.

### Partial output

A partial CSLC h5 is still on disk after the crash:

| File | Size | Note |
|---|--:|---|
| `work/product/.../t064_135523_iw2_20221016.h5` (run 2) | 200,456,689 bytes (191 MB) | partial; baseline produces 259 MB |

`tools/verify_output.py` was not run on this artifact (the harness
gates it on a clean exit, which py-spy did not deliver).

### Flamegraph

`logs_pyspy_20260508/pyspy.svg` (132 KB) covers the ~46 s window from
`py-spy record` start until the traced process died. Because the
workload is truncated at h5py close (i.e. the very end of the geocode
phase), **the flamegraph does not reflect a complete SAFE → CSLC run**
and any inclusive-time numbers extracted from it will be biased toward
pre-write phases. Region breakdown is therefore deferred to a future
session in which py-spy completes a clean run.

## Findings

- **Reproducible, not flaky.** Two consecutive runs failed at the
  identical stack frame and with the identical errno. Rerun is unlikely
  to recover.
- **py-spy-specific.** Baseline (no profiler) and cProfile (in-process
  deterministic profiler) both complete cleanly on the same workload,
  same image, same host, same NAS-backed `logs_*/` output path. Only
  the py-spy-attached run fails.
- **No sampler error.** py-spy reports `Errors: 0` despite the traced
  process crashing — the sampler successfully collected 4,714 stack
  traces over the lifetime of the traced process.
- **Harness gap.** `/usr/bin/time -v` in `run_profile_pyspy.sh` currently
  wraps `py-spy record`, so the reported `Max RSS` is the launcher's,
  not the workload's. Note for the harness, not a profiling result.

## Per-step deep dives (as needed)

Deferred to a future session. The expected next step is to root-cause
the py-spy + h5py close interaction (errno 103 = `ECONNABORTED`,
unusual in pure-file context) — explicitly out of scope for this
session per the run plan.
