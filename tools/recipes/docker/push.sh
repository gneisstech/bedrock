#!/usr/bin/env bash
# usage: push.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-}"

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

function read_helm_values_as_json () {
  yq r --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function get_docker_registry_name() {
  get_docker_repo_name | sed -e 's|\/.*||'
}

function attach_docker_registry () {
  az acr login -n "$(get_docker_registry_name)"
}

function push () {
  attach_docker_registry
  docker push "$(get_docker_repo_name):bedrock"
}

set -x
push || true
