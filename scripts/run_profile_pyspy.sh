#!/usr/bin/env bash
# Sample SAFE -> CSLC end-to-end with py-spy and emit a flamegraph SVG.
#
# Outputs (all under LOG_DIR, all gitignored):
#   pyspy.svg           flamegraph
#   run.log             stdout/stderr
#   run.time            /usr/bin/time -v rusage
#   runconfig.yaml      rendered runconfig
#   work/product/...    CSLC output (incidental, profiling does not skip it)

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "$(dirname "$0")/lib/resolve_log_dir.sh"
LOG_DIR="$(resolve_log_dir pyspy "${1:-}")"

source "$(dirname "$0")/lib/setup_ulimit.sh"
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/compose_run.sh"

LOG="${LOG_DIR}/run.log"
TIMEFILE="${LOG_DIR}/run.time"

{
    echo "py-spy profile run started at $(date -Iseconds)"
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

# 2. Launch CSLC under py-spy record.
#   --rate 100      100Hz sampling (matches mintpy-benchmark)
#   --idle          count sleeping threads too (surfaces I/O waits)
#   --subprocesses  ISCE3 may fork helper processes; follow them
START=$(date +%s)

compose_run "${LOG_DIR}" bash -c '
set -u
export PYTHONUNBUFFERED=1
/usr/bin/time -v -o /logs/run.time \
    py-spy record \
        -o /logs/pyspy.svg \
        --format flamegraph \
        --rate 100 \
        --idle \
        --subprocesses \
        -- s1_cslc.py --grid geo /logs/runconfig.yaml
' 2>&1 | tee -a "${LOG}"
EC=${PIPESTATUS[0]}

END=$(date +%s)
WALL_OUTER=$(( END - START ))

{
    echo
    echo "py-spy profile finished at $(date -Iseconds), exit=${EC}"
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

exit "${EC}"
