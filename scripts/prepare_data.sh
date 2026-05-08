#!/usr/bin/env bash
# Fetch the SAFE / orbit / DEM / burst_map / corner-reflector files for the
# Zenodo 7668411 benchmark dataset into fixtures/data/. URL convention follows
# COMPASS/tests/conftest.py's `download_if_needed`.
#
# The downloads run on the host (rather than inside the bench container) for
# simplicity; fixtures/data/ is gitignored and machine-local anyway.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${REPO_ROOT}/fixtures/data"
ORBIT_DIR="${DATA_DIR}/orbits"

mkdir -p "${DATA_DIR}" "${ORBIT_DIR}"

ZENODO_BASE="https://zenodo.org/record/7668411/files"

# File set referenced from COMPASS/tests/conftest.py:101-104.
FILES_AT_ROOT=(
    "S1A_IW_SLC__1SDV_20221016T015043_20221016T015111_045461_056FC0_6681.zip"
    "test_dem.tiff"
    "test_burst_map.sqlite3"
    "2022-10-16_0000_Rosamond-corner-reflectors.csv"
)

FILES_AT_ORBIT=(
    "S1A_OPER_AUX_POEORB_OPOD_20221105T083813_V20221015T225942_20221017T005942.EOF"
)

download_if_needed() {
    local dst="$1"
    local url="$2"
    if [ -s "${dst}" ]; then
        echo "[prepare_data] exists: ${dst} ($(du -h "${dst}" | awk '{print $1}'))"
        return 0
    fi
    echo "[prepare_data] downloading ${url}"
    # Zenodo occasionally redirects or rate-limits; retry generously.
    curl -fL --retry 5 --retry-delay 5 -o "${dst}.partial" "${url}"
    mv "${dst}.partial" "${dst}"
    echo "[prepare_data] saved: ${dst} ($(du -h "${dst}" | awk '{print $1}'))"
}

for f in "${FILES_AT_ROOT[@]}"; do
    download_if_needed "${DATA_DIR}/${f}" "${ZENODO_BASE}/${f}"
done

# Orbit files live at the Zenodo record root, but COMPASS's runconfig expects
# them under an orbits/ subdirectory. Save into the local subdir directly.
for f in "${FILES_AT_ORBIT[@]}"; do
    download_if_needed "${ORBIT_DIR}/${f}" "${ZENODO_BASE}/${f}"
done

# The TEC fixture jplg3190.15i is not on Zenodo — it ships with COMPASS's own
# tests/data/. Copy it across (the benchmark is read-only against COMPASS).
TEC_SRC="${REPO_ROOT}/../tests/data/jplg3190.15i"
TEC_DST="${DATA_DIR}/jplg3190.15i"
if [ -s "${TEC_DST}" ]; then
    echo "[prepare_data] exists: ${TEC_DST}"
elif [ -s "${TEC_SRC}" ]; then
    echo "[prepare_data] copying TEC fixture from COMPASS tests/data/"
    cp "${TEC_SRC}" "${TEC_DST}"
else
    echo "[prepare_data] WARN: ${TEC_SRC} not found." \
         "Runtime will fail unless TEC correction is disabled in the runconfig." >&2
fi

echo "[prepare_data] all files present under ${DATA_DIR}"
ls -lh "${DATA_DIR}" "${ORBIT_DIR}"
