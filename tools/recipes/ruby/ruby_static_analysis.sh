#!/usr/bin/env bash
# usage: ruby_static_analysis.sh

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

function repo_root () {
    git rev-parse --show-toplevel
}

function get_helm_chart_name() {
  ls "${BEDROCK_INVOKED_DIR}/helm"
}

function get_helm_values_file_name() {
  printf "%s/helm/%s/values.yaml" "${BEDROCK_INVOKED_DIR}" "$(get_helm_chart_name)"
}

function read_helm_values_as_json() {
  yq eval-all --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function ruby_static_analysis () {
  local container_path
  container_path="$(get_docker_repo_name):bedrock"
  docker run \
    --rm \
    "${container_path}" \
    /assets/run_ruby_static_analysis.sh
}

ruby_static_analysis
