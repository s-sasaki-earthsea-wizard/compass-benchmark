# Thin wrapper around scripts/*.sh. Run `make help` to list targets.
#
# Argument-passing contract:
#   - LOG_DIR: per-run output directory. Empty/unset falls through to a
#              timestamped logs_<tag>_<ts>/ directory under
#              $${BENCH_LOG_BASE:-$$HOME/compass-bench-logs}. Passed
#              positionally as the first script argument.
#   - BENCH_LOG_BASE: base dir for runs when LOG_DIR is not set. Defaults
#              to $$HOME/compass-bench-logs (host-local; off NAS to avoid
#              CIFS / py-spy interaction documented in issue #2).
#   - Other environment variables (ULIMIT_FRACTION, etc.) follow normal
#     make export rules; scripts read them directly.
#
# Usage examples:
#   make build
#   make prepare-data
#   make smoke
#   make baseline
#   make profile-pyspy
#   make profile-cprofile
#   make baseline LOG_DIR=/tmp/one_off_logs_001    # override per call
#   BENCH_LOG_BASE=/mnt/local-ssd/bench make profile-pyspy  # override base

.DEFAULT_GOAL := help
.PHONY: help build prepare-data smoke baseline profile-pyspy profile-cprofile clean

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## "; print "Targets:" } \
	      /^[a-zA-Z_-]+:.*## / { printf "  %-18s %s\n", $$1, $$2 }' \
	     $(MAKEFILE_LIST)

build: ## Build base + bench Docker images (~30 min on first run)
	bash scripts/build_image.sh

prepare-data: ## Download Zenodo 7668411 fixtures into fixtures/data/
	bash scripts/prepare_data.sh

smoke: ## Smoke test (compass import + py-spy ptrace + fixture sanity)
	bash scripts/run_smoke.sh "$(LOG_DIR)"

baseline: ## E2E baseline run (wall/RSS only, no profiler)
	bash scripts/run_baseline.sh "$(LOG_DIR)"

profile-pyspy: ## py-spy flamegraph (E2E)
	bash scripts/run_profile_pyspy.sh "$(LOG_DIR)"

profile-cprofile: ## cProfile pstats + markdown summary (E2E)
	bash scripts/run_profile_cprofile.sh "$(LOG_DIR)"

clean: ## Delete logs_*/ directories (also covered by .gitignore)
	rm -rf logs_*/
