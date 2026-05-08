# compass-benchmark image: a thin layer over the COMPASS production image that
# adds py-spy and other profiling helpers. The base `opera/cslc_s1:final_0.5.6`
# is built from COMPASS's own docker/Dockerfile via `bash build_docker_image.sh`
# (scripts/build_image.sh chains both builds in order).
#
# Inherited from the base image:
#   - USER:       compass_user
#   - WORKDIR:    /home/compass_user/scratch
#   - ENTRYPOINT: ["conda", "run", "--no-capture-output", "-n", "COMPASS"]
ARG BASE_IMAGE=opera/cslc_s1:final_0.5.6
FROM ${BASE_IMAGE}

# The base image's SHELL directive does not propagate to derived images, so we
# re-declare it here to ensure RUN commands execute inside the COMPASS conda env.
SHELL ["conda", "run", "--no-capture-output", "-n", "COMPASS", "/bin/bash", "-c"]

# Install profilers into the COMPASS conda env via plain pip.
# Docker already isolates from the host, so an extra venv layer (uv, virtualenv)
# would be over-engineering — we install straight into the conda env's site-packages.
COPY requirements.txt /tmp/requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Mount points for runtime bind mounts. The actual sources are wired up by
# docker-compose.yml: /workspace <- compass-benchmark/, /data <- fixtures/data,
# /logs <- per-run LOG_DIR.
USER root
RUN mkdir -p /workspace /data /logs \
    && chown -R compass_user:compass_user /workspace /data /logs
USER compass_user

WORKDIR /workspace

# ENTRYPOINT (`conda run -n COMPASS`) is inherited from the base; do not override.
# CMD defaults to bash so individual commands can be passed via `docker compose run`.
CMD ["/bin/bash"]
