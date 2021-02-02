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
declare -rx DD_CLIENT_API_KEY="${DD_CLIENT_API_KEY:-}"
declare -rx DD_CLIENT_APP_KEY="${DD_CLIENT_APP_KEY:-}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function init_bedrock_tools () {
  SECONDS=0
  docker pull gneisstech/bedrock_tools:latest
  "$(repo_root)/ci/recipes/report_metric_to_datadog.sh" 'init_bedrock' "${SECONDS}"
}

init_bedrock_tools "$@" 2> >(while read -r line; do (echo "LOGGING: $line"); done)
echo
