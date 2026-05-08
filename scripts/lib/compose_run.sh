# Shared wrapper around `docker compose run --rm bench ...`.
#
# Responsibilities:
#   - resolve REPO_ROOT (compass-benchmark/) regardless of CWD
#   - export LOG_DIR so docker-compose.yml can bind-mount it as /logs
#   - mkdir -p the LOG_DIR on the host so the bind mount target exists
#     (Docker would otherwise silently create a root-owned directory)
#   - forward arbitrary command + args into the container
#
# Usage:
#   source scripts/lib/compose_run.sh
#   compose_run <log_dir> <cmd...>
#
# Example:
#   compose_run "${LOG_DIR}" python -c "import compass; print(compass.__version__)"

compose_run() {
    local log_dir="$1"
    shift

    if [ -z "${log_dir}" ]; then
        echo "[compose_run] error: LOG_DIR is empty" >&2
        return 2
    fi

    # ${REPO_ROOT} is expected to be set by the caller. compose_run does not
    # second-guess the caller's path resolution.
    if [ -z "${REPO_ROOT:-}" ]; then
        echo "[compose_run] error: REPO_ROOT not set" >&2
        return 2
    fi

    mkdir -p "${log_dir}"

    # Use absolute path for LOG_DIR so docker-compose.yml's bind mount works
    # regardless of where the user invoked make from.
    local abs_log_dir
    abs_log_dir="$(cd "${log_dir}" && pwd)"

    LOG_DIR="${abs_log_dir}" \
        docker compose \
            -f "${REPO_ROOT}/docker/docker-compose.yml" \
            run --rm bench "$@"
}
