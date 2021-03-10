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
declare -rx HOST_HOME="${HOST_HOME:-}"
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"
declare -rx BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}"
declare -rx BEDROCK_MAX_ALLOWED_CVE_HIGH="${BEDROCK_MAX_ALLOWED_CVE_HIGH:0}"
declare -rx BEDROCK_MAX_ALLOWED_CVE_MEDIUM="${BEDROCK_MAX_ALLOWED_CVE_MEDIUM:2}"

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
  yq eval-all --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function get_docker_registry_host() {
  get_docker_repo_name | sed -e 's|\/.*||'
}

function get_docker_registry_name() {
  get_docker_registry_host | sed -e 's|\..*||'
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
  if [[ "${BEDROCK_CLUSTER}" == "" ]]; then
    get_helm_chart_name | sed -e 's|-.*||'
  else
    printf '%s' "${BEDROCK_CLUSTER}" | sed -e 's|_.*||' | tr '[:upper:]' '[:lower:]'
  fi
}

function get_project_prefix_uc() {
  get_project_prefix | tr '[:lower:]' '[:upper:]'
}

function get_devops_vault() {
  printf '%s-devops-kv' "$(get_project_prefix)"
}

function get_neuvector_license() {
  get_vault_secret "$(get_devops_vault)" 'neuvector-license'
}

function show_cve_high () {
  local -r results_file="${1}"
  jq '[.report.vulnerabilities[] | select(.severity == "High")]' "${results_file}"
}

function show_cve_medium () {
  local -r results_file="${1}"
  jq '[.report.vulnerabilities[] | select(.severity == "Medium")]' "${results_file}"
}

function fail_cve_high () {
  local -r results_file="${1}"
  local -r max_allowed="${2}"
  local count_cve
  count_cve="$(show_cve_high "${results_file}" | jq 'length')"
  if (( count_cve > max_allowed )); then
    printf "Too Many High priority CVE [%d] > limit [%d]\n" "${count_cve}" "${max_allowed}"
    false
  fi
}

function fail_cve_medium () {
  local -r results_file="${1}"
  local -r max_allowed="${2}"
  local count_cve
  count_cve="$(show_cve_medium "${results_file}" | jq 'length')"
  if (( count_cve > max_allowed )); then
    printf "Too Many Medium priority CVE [%d] > limit [%d]\n" "${count_cve}" "${max_allowed}"
    false
  fi
}

function attach_docker_registry () {
  az acr login -n "$(get_docker_registry_name)"
}

function neuvector_scanner () {
  local -r local_shared_dir="$(pwd)/ci_pipeline_home"
  local -r host_shared_dir="${HOST_HOME}/ci_pipeline_home"
  local -r scan_result="${local_shared_dir}/scan_result.json"

  attach_docker_registry
  mkdir -p "${local_shared_dir}"
  chmod 777 "${local_shared_dir}"
  docker run \
    --name neuvector.scanner \
    --rm \
    -e SCANNER_REPOSITORY="$(get_docker_repo_name)" \
    -e SCANNER_TAG='bedrock' \
    -e SCANNER_LICENSE="$(get_neuvector_license)" \
    --volume '/var/run/docker.sock:/var/run/docker.sock' \
    --volume "${host_shared_dir}:/var/neuvector" \
    "$(get_docker_registry_host)/neuvector/scanner:latest"
  printf "======== High priority CVE ========\n"
  show_cve_high "${scan_result}"
  printf "======== Medium priority CVE ========\n"
  show_cve_medium "${scan_result}"
  fail_cve_high "${scan_result}" "${BEDROCK_MAX_ALLOWED_CVE_HIGH}"
  fail_cve_medium "${scan_result}" "${BEDROCK_MAX_ALLOWED_CVE_MEDIUM}"
  printf "======== CVE checks passed --------\n"
}

neuvector_scanner "$@"
