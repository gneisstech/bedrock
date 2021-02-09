#!/usr/bin/env bash
# usage: init_bedrock_tools.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx DD_SECRET_VAULT="${DD_SECRET_VAULT:-}"
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-$(pwd)}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function init_bedrock_tools () {
  SECONDS=0
  docker pull gneisstech/bedrock_tools:latest
  "${BEDROCK_INVOKED_DIR}/.bedrock/ci/recipes/report_metric_to_datadog.sh" 'init_bedrock' "${SECONDS}"
}

init_bedrock_tools "$@" 2> >(while read -r line; do (echo "LOGGING: $line"); done)
echo
