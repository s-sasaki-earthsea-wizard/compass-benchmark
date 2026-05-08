#!/usr/bin/env bash
# E2E baseline: run SAFE -> CSLC without a profiler attached. Captures wall
# time and Max RSS via /usr/bin/time -v. Numerical findings are transcribed
# into reports/report_baseline.md by hand.
#
# Outputs (all under LOG_DIR, all gitignored):
#   runconfig.yaml      rendered runconfig
#   run.log             stdout/stderr
#   run.time            /usr/bin/time -v rusage
#   work/product/...    CSLC output h5
#   work/scratch/...    intermediate scratch
#   verify.log          tools.verify_output result

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/resolve_log_dir.sh"
LOG_DIR="$(resolve_log_dir baseline "${1:-}")"

source "$(dirname "$0")/lib/setup_ulimit.sh"
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/compose_run.sh"

LOG="${LOG_DIR}/run.log"
TIMEFILE="${LOG_DIR}/run.time"

{
    echo "Baseline run started at $(date -Iseconds)"
    echo "REPO_ROOT: ${REPO_ROOT}"
    echo "LOG_DIR:   ${LOG_DIR}"
    echo
    uname -a
    echo "---"
    free -h 2>/dev/null || true
    echo "---"
    docker --version
    echo
} | tee "${LOG}"

# 1. Render the runconfig (inside the container).
echo "[baseline] rendering runconfig" | tee -a "${LOG}"
compose_run "${LOG_DIR}" python -m tools.render_runconfig \
    --template /workspace/fixtures/geo_cslc_s1_template.yaml \
    --output /logs/runconfig.yaml \
    --data-path /data \
    --test-path /logs/work \
    --burst-id t064_135523_iw2 2>&1 | tee -a "${LOG}"

# 2. Run CSLC (geo grid). /usr/bin/time runs inside the container so it does
#    not include docker compose startup overhead; the outer wall is measured
#    separately for transparency.
echo "[baseline] launching s1_cslc.py --grid geo" | tee -a "${LOG}"
START=$(date +%s)

compose_run "${LOG_DIR}" bash -c '
set -u
export PYTHONUNBUFFERED=1
/usr/bin/time -v -o /logs/run.time \
    s1_cslc.py --grid geo /logs/runconfig.yaml
' 2>&1 | tee -a "${LOG}"
EC=${PIPESTATUS[0]}

END=$(date +%s)
WALL_OUTER=$(( END - START ))

{
    echo
    echo "Baseline run finished at $(date -Iseconds), exit=${EC}"
    echo "Outer wall (incl. compose startup): ${WALL_OUTER} s"
} | tee -a "${LOG}"

if [ -f "${TIMEFILE}" ]; then
    WALL=$(awk -F': ' '/Elapsed \(wall clock\)/ {print $2}' "${TIMEFILE}")
    RSS=$(awk -F': ' '/Maximum resident set size/ {print $2}' "${TIMEFILE}")
    echo "Inner wall (s1_cslc only):          ${WALL}" | tee -a "${LOG}"
    echo "Max RSS:                            ${RSS} KB" | tee -a "${LOG}"
fi

# 3. Verify the produced CSLC h5.
if [ "${EC}" -eq 0 ]; then
    echo "[baseline] verifying CSLC h5" | tee -a "${LOG}"
    compose_run "${LOG_DIR}" python -m tools.verify_output \
        --hdf5 /logs/work/product/t064_135523_iw2/20221016/t064_135523_iw2_20221016.h5 \
        2>&1 | tee "${LOG_DIR}/verify.log" | tee -a "${LOG}"
fi

exit "${EC}"
