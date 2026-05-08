#!/usr/bin/env bash
# Build the compass-benchmark Docker image, building the COMPASS base image
# first if it is missing on this host.
#
# First run is heavy (~30 minutes, several GBs) because it provisions a full
# conda env plus RAiDER and s1-reader. Subsequent runs hit the layer cache.
#
# No arguments.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPASS_ROOT="$(cd "${REPO_ROOT}/.." && pwd)"
BASE_IMAGE_TAG="opera/cslc_s1:final_0.5.6"
BENCH_IMAGE_TAG="compass-benchmark:latest"

echo "[build_image] REPO_ROOT     = ${REPO_ROOT}"
echo "[build_image] COMPASS_ROOT  = ${COMPASS_ROOT}"
echo "[build_image] BASE image    = ${BASE_IMAGE_TAG}"
echo "[build_image] BENCH image   = ${BENCH_IMAGE_TAG}"

# 1. Build the COMPASS base image if it is not already present.
if docker image inspect "${BASE_IMAGE_TAG}" >/dev/null 2>&1; then
    echo "[build_image] base image already present, skipping base build"
else
    echo "[build_image] base image not found, invoking COMPASS/build_docker_image.sh"
    if [ ! -x "${COMPASS_ROOT}/build_docker_image.sh" ]; then
        echo "[build_image] error: ${COMPASS_ROOT}/build_docker_image.sh not found or not executable" >&2
        exit 1
    fi
    (
        cd "${COMPASS_ROOT}"
        bash build_docker_image.sh
    )
fi

# 2. Build the bench-derived image on top of the base.
echo "[build_image] building ${BENCH_IMAGE_TAG}"
docker build \
    --tag "${BENCH_IMAGE_TAG}" \
    --build-arg "BASE_IMAGE=${BASE_IMAGE_TAG}" \
    -f "${REPO_ROOT}/docker/Dockerfile" \
    "${REPO_ROOT}"

echo "[build_image] done"
docker image ls | grep -E "(opera/cslc_s1|compass-benchmark)" || true
