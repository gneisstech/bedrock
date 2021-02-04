#!/usr/bin/env bash
# usage: bless_development_artifacts.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-}"
declare -rx BUILD_BUILDNUMBER="${BUILD_BUILDNUMBER:-}"
declare -rx BUILD_DEFINITIONNAME="${BUILD_DEFINITIONNAME:-}"

# Arguments
# ---------------------

function repo_root() {
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

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function get_project_prefix() {
  get_helm_chart_name | sed -e 's|-.*||'
}

function get_project_prefix_uc() {
  get_project_prefix | tr [a-z] [A-Z]
}

function get_devops_vault() {
  printf '%s-devops-kv' "$(get_project_prefix)"
}

function get_bd_token() {
  get_vault_secret "$(get_devops_vault)" 'bd-token'
}

function get_bd_url() {
  get_vault_secret "$(get_devops_vault)" 'bd-url'
}

function attach_docker_registry () {
  az acr login -n "$(get_docker_registry_name)"
}

function blackduck_scanner() {
  attach_docker_registry

  bash <(curl -s -L https://detect.synopsys.com/detect.sh) \
    --detect.blackduck.signature.scanner.individual.file.matching=ALL \
    --detect.blackduck.signature.scanner.dry.run=false \
    --blackduck.api.token="$(get_bd_token)" \
    --blackduck.url="$(get_bd_url)" \
    --detect.blackduck.signature.scanner.paths="${BEDROCK_INVOKED_DIR}" \
    --detect.blackduck.signature.scanner.exclusion.pattern.search.depth=100 \
    --detect.project.name="$(get_project_prefix_uc)-${BUILD_DEFINITIONNAME}" \
    --detect.project.version.name="${BUILD_BUILDNUMBER}" \
    --detect.docker.image="$(get_docker_repo_name):bedrock"
}

set -x
blackduck_scanner "$@" || true
