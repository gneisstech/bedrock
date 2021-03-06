#!/usr/bin/env bash
# usage: pre_build_housekeeping.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function pre_build_housekeeping() {
  if [[ -e "${BEDROCK_INVOKED_DIR}/go.mod" ]]; then
    /bedrock/recipes/golang/go_module_fetch_vendor_folder.sh
  fi
}

pre_build_housekeeping
