#!/usr/bin/env bash
# Profile SAFE -> CSLC end-to-end with cProfile (deterministic). Produces a
# pstats binary plus markdown summaries sorted by cumulative time and self time.
#
# Outputs (all under LOG_DIR, all gitignored):
#   cprofile.prof           pstats binary
#   cprofile_summary.md     markdown view sorted by cumtime
#   cprofile_tottime.md     markdown view sorted by tottime (self time)
#   run.log                 stdout/stderr
#   run.time                /usr/bin/time -v rusage
#   runconfig.yaml          rendered runconfig
#
# Note: cProfile carries a 10-30% overhead vs. an unprofiled run. Use
# scripts/run_baseline.sh for clean wall-time numbers.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/resolve_log_dir.sh"
LOG_DIR="$(resolve_log_dir cprofile "${1:-}")"

source "$(dirname "$0")/lib/setup_ulimit.sh"
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/compose_run.sh"

LOG="${LOG_DIR}/run.log"
TIMEFILE="${LOG_DIR}/run.time"

{
    echo "cProfile run started at $(date -Iseconds)"
    echo "LOG_DIR: ${LOG_DIR}"
    echo
} | tee "${LOG}"

# 1. Render the runconfig.
compose_run "${LOG_DIR}" python -m tools.render_runconfig \
    --template /workspace/fixtures/geo_cslc_s1_template.yaml \
    --output /logs/runconfig.yaml \
    --data-path /data \
    --test-path /logs/work \
    --burst-id t064_135523_iw2 2>&1 | tee -a "${LOG}"

# 2. Launch CSLC under cProfile.
#    s1_cslc.py is a console script, so we resolve its path with `which` and
#    pass it as the script argument to `python -m cProfile`.
START=$(date +%s)

compose_run "${LOG_DIR}" bash -c '
set -u
export PYTHONUNBUFFERED=1
# `which` is not installed in the Oracle Linux base image. POSIX
# `command -v` is a builtin and always available.
S1_CSLC=$(command -v s1_cslc.py)
if [ -z "${S1_CSLC}" ]; then
    echo "[cprofile] s1_cslc.py not found on PATH" >&2
    exit 1
fi
/usr/bin/time -v -o /logs/run.time \
    python -m cProfile -o /logs/cprofile.prof \
        "${S1_CSLC}" --grid geo /logs/runconfig.yaml
' 2>&1 | tee -a "${LOG}"
EC=${PIPESTATUS[0]}

END=$(date +%s)
WALL_OUTER=$(( END - START ))

{
    echo
    echo "cProfile run finished at $(date -Iseconds), exit=${EC}"
    echo "Outer wall: ${WALL_OUTER} s"
} | tee -a "${LOG}"

if [ -f "${TIMEFILE}" ]; then
    WALL=$(awk -F': ' '/Elapsed \(wall clock\)/ {print $2}' "${TIMEFILE}")
    RSS=$(awk -F': ' '/Maximum resident set size/ {print $2}' "${TIMEFILE}")
    {
        echo "Inner wall: ${WALL}"
        echo "Max RSS:    ${RSS} KB"
    } | tee -a "${LOG}"
fi

# 3. Render the pstats binary into markdown summaries.
if [ "${EC}" -eq 0 ] && [ -s "${LOG_DIR}/cprofile.prof" ]; then
    echo "[cprofile] generating markdown summary" | tee -a "${LOG}"
    compose_run "${LOG_DIR}" python -m tools.parse_cprofile \
        --input /logs/cprofile.prof \
        --output /logs/cprofile_summary.md \
        --top 50 \
        --sort cumulative 2>&1 | tee -a "${LOG}"
    # Self-time view: surfaces functions where the work itself is heavy
    # rather than where the call stack is deep.
    compose_run "${LOG_DIR}" python -m tools.parse_cprofile \
        --input /logs/cprofile.prof \
        --output /logs/cprofile_tottime.md \
        --top 50 \
        --sort tottime 2>&1 | tee -a "${LOG}"
fi

exit "${EC}"
