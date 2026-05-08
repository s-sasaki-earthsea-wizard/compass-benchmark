# Resolve the absolute LOG_DIR for a given run script.
#
# Policy (highest precedence first):
#   1. ${1} (a fully-qualified path passed as the first script argument)
#   2. ${BENCH_LOG_BASE}/logs_<tag>_<ts>  (env-var override of the base dir)
#   3. ${HOME}/compass-bench-logs/logs_<tag>_<ts>  (default base dir)
#
# The default base dir is intentionally NOT under ${REPO_ROOT}. The repo lives
# on a CIFS / SMB-backed NAS in this project's primary host, and py-spy's
# ptrace attach + signal traffic interacts badly with the CIFS client during
# h5py.File.close — see compass-benchmark issue #2 / 2026-05-09 session note.
# Keeping bench artifacts on a host-local POSIX filesystem (e.g. ext4 under
# ${HOME}) avoids that failure mode and also keeps the NAS write path quiet
# when running long, write-heavy benchmarks.
#
# Usage:
#   source "$(dirname "$0")/lib/resolve_log_dir.sh"
#   LOG_DIR="$(resolve_log_dir <tag> "${1:-}")"
#
# Example:
#   LOG_DIR="$(resolve_log_dir pyspy "${1:-}")"
#
# Returns: an absolute path. Creates the directory if it does not exist.

resolve_log_dir() {
    local tag="$1"
    local override="${2:-}"

    if [ -z "${tag}" ]; then
        echo "[resolve_log_dir] error: tag is required" >&2
        return 2
    fi

    local target
    if [ -n "${override}" ]; then
        target="${override}"
    else
        local base="${BENCH_LOG_BASE:-${HOME}/compass-bench-logs}"
        target="${base}/logs_${tag}_$(date +%Y%m%d_%H%M%S)"
    fi

    mkdir -p "${target}"
    (cd "${target}" && pwd)
}
