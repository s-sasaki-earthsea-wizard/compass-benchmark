# Thin wrapper around scripts/*.sh. Run `make help` to list targets.
#
# Argument-passing contract:
#   - LOG_DIR: per-run output directory. Empty/unset falls through to a
#              timestamped logs_<tag>_<ts>/ directory chosen by the script.
#              Passed positionally as the first script argument.
#   - Environment variables (ULIMIT_FRACTION, etc.) follow normal make export
#     rules; scripts read them directly.
#
# Usage examples:
#   make build
#   make prepare-data
#   make smoke
#   make baseline LOG_DIR=logs_baseline_001
#   make profile-pyspy
#   make profile-cprofile LOG_DIR=logs_cprof_001

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
