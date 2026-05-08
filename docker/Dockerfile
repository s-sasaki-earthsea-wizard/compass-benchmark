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
# COPY defaults to root ownership; the base image switches USER to compass_user
# before this FROM, so the subsequent rm would fail without an explicit --chown.
COPY --chown=compass_user:compass_user requirements.txt /tmp/requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Grant py-spy file capabilities so the non-root compass_user can ptrace.
# Background: docker-compose.yml sets `cap_add: SYS_PTRACE`, which puts the
# capability into the container's bounding set, but for non-root processes the
# capability is NOT lifted into the effective set automatically. The fix is to
# tag the py-spy binary itself with `cap_sys_ptrace+eip` so the capability is
# inherited into the effective set on exec.
#
# `libcap` and GNU `time` (for `/usr/bin/time -v` rusage in run_baseline.sh
# and the profile scripts) are not in the base image, so install them here.
# yum is invoked once in this layer to keep the image lean.
#
# Mount points for runtime bind mounts (/workspace, /data, /logs) are also
# created in this same root step to avoid an extra USER toggle.
USER root
RUN yum -y install libcap time \
    && yum clean all \
    && setcap cap_sys_ptrace+eip /home/compass_user/miniforge3/envs/COMPASS/bin/py-spy \
    && getcap /home/compass_user/miniforge3/envs/COMPASS/bin/py-spy \
    && mkdir -p /workspace /data /logs \
    && chown -R compass_user:compass_user /workspace /data /logs
USER compass_user

WORKDIR /workspace

# ENTRYPOINT (`conda run -n COMPASS`) is inherited from the base; do not override.
# CMD defaults to bash so individual commands can be passed via `docker compose run`.
CMD ["/bin/bash"]
