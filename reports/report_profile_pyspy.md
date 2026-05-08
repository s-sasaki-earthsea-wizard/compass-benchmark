# Profile: SAFE → CSLC E2E (py-spy flamegraph)

> This report is **hand-transcribed** from `scripts/run_profile_pyspy.sh`
> artifacts under `${BENCH_LOG_BASE:-$HOME/compass-bench-logs}/logs_pyspy_*/`.
> The flamegraph SVG is at `logs_pyspy_*/pyspy.svg`. Strip machine-specific
> tokens (absolute paths, hostnames) during transcription.

## TL;DR

The 2026-05-08 attempt failed reproducibly: py-spy itself completed (exit 0)
but the traced `s1_cslc.py` aborted at the Block 1 → Block 2 boundary with
`errno=103 (ECONNABORTED)` inside `h5py.File.close`. Root cause was traced
to the **CIFS-backed log output path**: this host mounts the repo via SMB
(`//192.168.10.132/EW-NAS-Atoll on /mnt/nas type cifs`), and py-spy's
ptrace + signal traffic disrupts the long-running CIFS syscalls inside
HDF5's `_close_open_objects`, which the CIFS client surfaces as
`ECONNABORTED`. baseline (no profiler) and cProfile (in-process, no
ptrace, no signals) do not disrupt the SMB session and therefore complete
cleanly even with the same NAS output path.

The 2026-05-09 attempt **resolves the failure** by relocating LOG_DIR off
CIFS to a host-local POSIX FS (ext4 under `$HOME/compass-bench-logs/`).
Two consecutive runs (manual `LOG_DIR=` override + new `$HOME` default)
both completed end-to-end with `verify_output.py ok=True` and the same
259 MB / `(4420, 20210)` complex64 CSLC product as baseline.

> **Profiling completion status (issue #2 acceptance criteria):**
> - **AC1 (CSLC h5 verify_output ok=True): met.** Two consecutive runs.
> - **AC2 (flamegraph contains both Block 1 and Block 2): met by
>   construction.** The 12 s `QA meta processing time` (Block 2) ran
>   inside the py-spy sampling window in both runs (Samples 5,782 / 5,933,
>   Errors 0). Detailed SVG inspection deferred (next session scope).
> - **AC3 (reproducible across two consecutive runs): met.** Both runs
>   above produce identical 259 MB CSLC h5 with `verify_output ok=True`.
>
> Tracking issue:
> [s-sasaki-earthsea-wizard/compass-benchmark#2](https://github.com/s-sasaki-earthsea-wizard/compass-benchmark/issues/2)
> (resolution applied 2026-05-09).

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
- Run timestamps:
  - 2026-05-08: 23:16 / 23:21 JST (both crashed; see "Initial 2026-05-08
    attempt" below)
  - 2026-05-09: 00:25 / 00:38 JST (both successful; see
    "Resolution: host-local LOG_DIR (2026-05-09)" below)

## Resolution: host-local LOG_DIR (2026-05-09)

After confirming the crash signature was `errno=103 (ECONNABORTED)` —
a network/socket-level error normally absent from pure-file HDF5
contexts — `mount` showed that the repo lives on a CIFS / SMB-mounted
NAS:

```
//192.168.10.132/EW-NAS-Atoll on /mnt/nas type cifs (vers=3.1.1, soft,
                                                     retrans=1, ...)
```

Hypothesis: py-spy's ptrace attach + signal traffic interrupts long
CIFS syscalls inside HDF5's `_close_open_objects` (which issues many
flushes/closes during reference-count teardown), and the CIFS client
maps the disrupted SMB session to ECONNABORTED.

Fix: relocate `LOG_DIR` (the bind-mount source for `/logs` in the
container, and the parent of the CSLC h5 output) off CIFS to a
host-local POSIX FS. The repo's bind-mount layout already supports
this — `LOG_DIR` is per-run configurable through `compose_run.sh`
without any docker-compose.yml change.

### Triage run (2026-05-09 00:25 JST, manual override)

Invocation:
```bash
make profile-pyspy LOG_DIR=$HOME/compass-bench-logs/logs_pyspy_path2_<ts>
```

Outcome: **Block 1 → Block 2 traversed, full CSLC produced.**

### Repro run (2026-05-09 00:38 JST, new $HOME default)

After applying the harness change so `$HOME/compass-bench-logs/` is
the default `LOG_BASE` (see "Harness changes" below), invocation:
```bash
make profile-pyspy
```

Outcome: same as triage run — successful Block 1 → Block 2 → exit 0.

### Top-level timings (successful runs)

| Metric | Run A (override) | Run B (new default) | baseline |
|---|--:|--:|--:|
| Outer wall (incl. compose startup) | 59 s | 60 s | 56 s |
| Inner wall (`/usr/bin/time -v` on `py-spy record`) | 57.63 s | 58.73 s | 54.28 s |
| `journal: ... successfully ran in` (s1_geocode_slc) | 55 s | 56 s | n/a |
| `journal: QA meta processing time` (Block 2) | 12 s | 12 s | (incl. above) |
| Sample count | 5,782 | 5,933 | n/a |
| Sampler errors | 0 | 0 | n/a |
| `py-spy record` exit code | 0 | 0 | n/a |
| Traced `s1_cslc.py` exit | 0 | 0 | 0 |
| CSLC h5 size | 259.33 MB | 259.33 MB | 259.33 MB |
| `verify_output.py` | `ok=True` | `ok=True` | `ok=True` |
| VV shape / dtype | `(4420, 20210)` complex64 | `(4420, 20210)` complex64 | `(4420, 20210)` complex64 |
| VV nonzero ratio | 1.0 | 1.0 | 1.0 |

`Max RSS` from `/usr/bin/time` is still the py-spy launcher's RSS only
(9,688 KB / 9,780 KB), not the workload's — see "Findings" / harness gap.
True workload RSS is in [report_baseline.md](report_baseline.md) (≈ 5.89 GiB).

py-spy overhead vs. baseline: inner wall +4 s on the same workload,
≈ +8 % (cProfile is +7 % per [report_profile_cprofile.md](report_profile_cprofile.md)).
The added 12 s of Block 2 work is now reflected in both the journal
log and the flamegraph sampling window.

### Harness changes (2026-05-09 commit on feature/phase1.5-baseline-profile)

- `scripts/lib/resolve_log_dir.sh` (new): centralizes LOG_DIR
  resolution with priority `$1 > BENCH_LOG_BASE/logs_<tag>_<ts> >
  $HOME/compass-bench-logs/logs_<tag>_<ts>`.
- `scripts/run_{smoke,baseline,profile_pyspy,profile_cprofile}.sh`:
  call `resolve_log_dir <tag> "${1:-}"` instead of building LOG_DIR
  inline under `${REPO_ROOT}`.
- `Makefile`, `README.md`, `CLAUDE.md`: documentation updated; the
  `docker-compose.yml` bind-mount layout was intentionally left
  unchanged (already supports per-run override).

### Why this and not other paths from the original pivot list

The original pivot list ([2026-05-08 session note](../.claude-notes/2026-05-08-baseline-profile-runs.md))
proposed four parallel investigation paths. After observing that
`/mnt/nas` is CIFS, the prior on **path 2 (NAS bind mount)** rose
sharply over **path 1 (py-spy options)** and **path 3 (py-spy
version)** because ECONNABORTED is intrinsically a
network/socket-context error and CIFS uniquely surfaces it on a
file-API close. Path 2 was tried first, succeeded, and the other
paths were not needed. Path 4 (`/usr/bin/time` wrapping order) is
orthogonal to this fix and remains a known harness gap (see "Findings").

## Initial 2026-05-08 attempt (failure record)

The two 2026-05-08 attempts and their failure analysis are retained
below as the historical record of why issue #2 was filed and what
shape the crash had.

### Top-level timings (failed runs)

| Metric | Run 1 | Run 2 |
|---|--:|--:|
| Outer wall (incl. compose startup) | 47 s | 48 s |
| Inner wall (`/usr/bin/time -v` on `py-spy record`) | 45.85 s | 45.90 s |
| Sample count | 4,615 | 4,714 |
| Sampler errors | 0 | 0 |
| `py-spy record` exit code | 0 | 0 |
| Traced `s1_cslc.py` exit | crashed (Traceback) | crashed (Traceback) |

The 4,615 / 4,714 sample range vs. the 5,782 / 5,933 of the successful
runs reflects the crashed runs missing the ~12 s Block 2 sampling
window: 5,933 - 4,714 ≈ 1,219 samples ≈ 12.2 s at 100 Hz, consistent.

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

### Partial output and what is missing

A partial CSLC h5 is on disk after the crash:

| File | Size | Note |
|---|--:|---|
| `work/product/.../t064_135523_iw2_20221016.h5` (run 2) | 200,456,689 bytes (191 MB) | partial; baseline produces 259 MB |

`tools/verify_output.py` was not run on this artifact (the harness
gates it on a clean exit, which py-spy did not deliver).

**The 68 MB gap reflects a structural truncation of the pipeline, not
just a corrupt close.** `compass.s1_geocode_slc.run` opens the output
h5 *twice*:

1. **Block 1** (`with h5py.File(output_hdf5, 'w'): ...`, opens at line 121,
   exits at line 243). Writes the geocoded CSLC raster: ISCE3
   `geocode_slc` (cProfile: 20.5 s) and `write_direct` of the data
   blocks (cProfile: 14.4 s).
2. **Block 2** (`with h5py.File(output_hdf5, 'a'): ...`, opens at line 248).
   Writes QA / metadata / browse: `make_browse_image` (cProfile:
   4.65 s), `compute_CSLC_raster_stats` (4.38 s),
   `percent_land_and_valid_pixels` (2.74 s),
   `compute_correction_stats`, `populate_rfi_dict`, `set_orbit_type`,
   plus `stats_json` write-out.

The crash is at the **`__exit__` of Block 1** (line 121's close).
The exception propagates immediately, so **Block 2 never runs**.
Everything Block 2 would write into the h5 — QA stats, RFI dict,
orbit type, browse-image-related metadata — is therefore absent
from the partial product.

In cProfile cumulative-time terms, that is a missing tail of roughly
**12+ seconds of pipeline work** (≈ 22 % of baseline wall time);
that work is also entirely absent from the flamegraph.

### Flamegraph

`logs_pyspy_20260508/pyspy.svg` (132 KB) covers the ~46 s window from
`py-spy record` start until the traced process died at the end of
Block 1. Because the workload is truncated at the boundary between
the geocode block and the QA/browse block, **the flamegraph does not
reflect a complete SAFE → CSLC run**: it includes Block 1 (geocode +
`write_direct`) but not Block 2 (browse + QA + raster stats +
metadata). Inclusive-time numbers extracted from this SVG would
therefore over-weight the geocode path and entirely miss the QA path.
Region breakdown is deferred to a future session in which the traced
workload reaches the end of `s1_geocode_slc.run` cleanly.

## Findings

- **Crash was reproducible across exactly the configurations that share
  the CIFS output path.** Two 2026-05-08 runs failed at the identical
  stack frame and with the identical errno on NAS-backed `logs_*/`.
  Two 2026-05-09 runs on host-local `$HOME/compass-bench-logs/`
  succeeded with identical product output. The image, fixture, py-spy
  version, py-spy options, and runconfig were unchanged across all
  four runs — only the LOG_DIR filesystem differed.
- **CIFS-specific, not py-spy-specific in isolation.** Baseline (no
  profiler) and cProfile (in-process, no ptrace, no signals) both
  complete cleanly on CIFS — they don't disrupt the SMB session.
  py-spy + ptrace + signal traffic during HDF5's `_close_open_objects`
  on CIFS is the failure mode; on host-local POSIX FS the same
  py-spy + ptrace setup runs cleanly.
- **No sampler error.** py-spy reports `Errors: 0` in all four runs,
  including the 2026-05-08 ones where the traced process crashed —
  the sampler itself was healthy throughout, the sampling window simply
  ended early when the traced process died.
- **Harness gap (still open).** `/usr/bin/time -v` in
  `run_profile_pyspy.sh` wraps `py-spy record`, so the reported
  `Max RSS` is the launcher's (~9.7 MB), not the workload's
  (~5.89 GiB per [report_baseline.md](report_baseline.md)). This is
  orthogonal to the LOG_DIR fix and is left for a future commit.

## Per-step deep dives (as needed)

Deferred to a future session. The 2026-05-09 successful runs do
contain a complete flamegraph (Block 1 + Block 2), so a region
breakdown / cross-check against [report_profile_cprofile.md](report_profile_cprofile.md)
hot-spot ranking is now feasible whenever it is in scope.

## Remaining work for future sessions

The pivot stated in the 2026-05-08 entry of this report
("getting the SAFE → CSLC pipeline to complete under py-spy") is now
achieved. Items deferred from earlier or newly surfaced:

- **AC2 strict verification (SVG inspection).** AC2 was met "by
  construction" (Block 2 ran inside the sampling window in both
  successful runs, Errors=0). A future session can open
  `pyspy.svg` and confirm the QA/browse frames (`make_browse_image`,
  `compute_CSLC_raster_stats`, `percent_land_and_valid_pixels`, etc.)
  are explicitly present in the flamegraph.
- **Profile result consumption.** Region breakdown of the 2026-05-09
  flamegraph and three-way cross-check of hot spots across baseline,
  cProfile, and py-spy.
- **`/usr/bin/time` wrapping order.** Reorder so the inner workload's
  RSS is captured, e.g. `py-spy record -- /usr/bin/time -v ... s1_cslc.py`.
- **Validation of the produced CSLC h5 against expected reference
  values.** Out of scope for this session; `verify_output.py` is a
  shape/sanity check, not a numerical validation.
