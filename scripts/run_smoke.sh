#!/usr/bin/env bash
# Smoke test — verify the plumbing without actually running CSLC end-to-end.
# Checks:
#   - the bench image starts and the COMPASS conda env is active
#   - `import compass` succeeds
#   - py-spy is installed and can ptrace another process (cap_add: SYS_PTRACE
#     and seccomp loosening are correctly wired)
#   - fixtures downloaded by prepare_data.sh are visible at /data
#
# No real CSLC processing is launched here.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${1:-${REPO_ROOT}/logs_smoke_$(date +%Y%m%d_%H%M%S)}"
LOG_DIR="$(mkdir -p "${LOG_DIR}" && cd "${LOG_DIR}" && pwd)"

source "$(dirname "$0")/lib/setup_ulimit.sh"
# shellcheck disable=SC1091
source "$(dirname "$0")/lib/compose_run.sh"

echo "[smoke] LOG_DIR = ${LOG_DIR}"

LOG="${LOG_DIR}/smoke.log"
{
    echo "Smoke test started at $(date -Iseconds)"
    echo "REPO_ROOT: ${REPO_ROOT}"
    echo
} | tee "${LOG}"

# 1. import compass
echo "[smoke] step 1: import compass" | tee -a "${LOG}"
compose_run "${LOG_DIR}" python -c "
import sys
import compass
import compass.utils.h5_helpers as h
print(f'python: {sys.version.split()[0]}')
print(f'compass module: {compass.__file__}')
print(f'DATA_PATH: {h.DATA_PATH}')
" 2>&1 | tee -a "${LOG}"

# 2. py-spy presence and version (just confirms the binary is on PATH)
echo "[smoke] step 2: py-spy --version" | tee -a "${LOG}"
compose_run "${LOG_DIR}" py-spy --version 2>&1 | tee -a "${LOG}"

# 3. fixture sanity
echo "[smoke] step 3: fixture sanity" | tee -a "${LOG}"
compose_run "${LOG_DIR}" bash -c "
ls -lh /data /data/orbits 2>&1
echo '---'
ls -lh /workspace/fixtures
" 2>&1 | tee -a "${LOG}"

# 4. Render a runconfig (no CSLC execution, just confirms tooling works)
echo "[smoke] step 4: render runconfig" | tee -a "${LOG}"
compose_run "${LOG_DIR}" python -m tools.render_runconfig \
    --template /workspace/fixtures/geo_cslc_s1_template.yaml \
    --output /logs/runconfig.yaml \
    --data-path /data \
    --test-path /logs/work \
    --burst-id t064_135523_iw2 2>&1 | tee -a "${LOG}"

# 5. py-spy ptrace check — final confirmation that SYS_PTRACE is in effect.
echo "[smoke] step 5: py-spy ptrace check" | tee -a "${LOG}"
compose_run "${LOG_DIR}" bash -c '
python -c "import time; time.sleep(3)" &
target_pid=$!
sleep 0.5
if py-spy dump --pid "${target_pid}" >/dev/null 2>&1; then
    echo "py-spy dump succeeded — SYS_PTRACE OK"
else
    echo "py-spy dump FAILED — SYS_PTRACE missing or seccomp blocking ptrace"
    wait "${target_pid}" 2>/dev/null
    exit 1
fi
wait "${target_pid}"
' 2>&1 | tee -a "${LOG}"
EC=${PIPESTATUS[0]}

{
    echo
    echo "Smoke test finished at $(date -Iseconds), exit=${EC}"
} | tee -a "${LOG}"

exit "${EC}"
