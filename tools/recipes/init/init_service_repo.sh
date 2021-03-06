#!/usr/bin/env bash
# usage: init_service_tree.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"
declare -rx BEDROCK_SERVICE="${BEDROCK_SERVICE:-}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function service_root () {
  printf '%s' "${BEDROCK_INVOKED_DIR}"
}

function get_helm_chart_name() {
  ls "$(service_root)/helm"
}

function service_name () {
  if [[ -z "${BEDROCK_SERVICE}" ]]; then
    get_helm_chart_name
  else
    printf '%s' "${BEDROCK_SERVICE}"
  fi
}

function get_helm_values_file_name() {
  printf "%s/helm/%s/values.yaml" "$(service_root)" "$(service_name)"
}

function read_helm_values_as_json () {
  yq eval-all --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function get_docker_registry_name() {
  get_docker_repo_name | sed -e 's|\/.*||'
}

function get_project_prefix() {
  get_helm_chart_name | sed -e 's|-.*||'
}

function get_project_prefix_uc() {
  get_project_prefix | tr '[:lower:]' '[:upper:]'
}

function create_template_folders () {
  mkdir -pf "$(service_root)/.bedrock/ci/recipes"
  mkdir -pf "$(service_root)/.bedrock/ci/pipelines/azure/service"
  mkdir -pf "$(service_root)/helm/$(service_name)"
}

function template_subst() {
  false
}

function template_cp() {
  local -r source="${1}"
  local -r target="${2}"
  template_subst "${source}" > "${target}"
}

function template_cp_dir() {
  local -r source="${1}"
  local -r target="${2}"
  template_subst "${source}" > "${target}"
}

function copy_dockerfile_if_needed() {
  local docker_filename
  docker_filename="$(service_root)/Dockerfile"
  if [[ ! -e "${docker_filename}" ]]; then
    # @@ TODO allow language specifier for initial dockerfile
    template_cp '/bedrock/templates/docker/Dockerfile' "${docker_filename}"
    git add "${docker_filename}"
  fi
}

function copy_helm_chart_if_needed() {
  local -r helm_repo_root="$(service_root)/helm/$(service_name)"
  if [[ ! -e "${helm_repo_root}/Chart.yaml" ]]; then
    template_cp_dir "/bedrock/templates/helm" "${helm_repo_root}"
    git add "${helm_repo_root}"
  fi
}

function copy_semver_if_needed() {
  local semver_filename
  semver_filename="$(service_root)/semver.txt"
  if [[ ! -e "${semver_filename}" ]]; then
    cp '/bedrock/templates/semver/semver.txt' "${semver_filename}"
    git add "${semver_filename}"
  fi
}

function copy_bedrock_recipes() {
  template_cp_dir "/bedrock/templates/recipes" "$(service_root)/.bedrock/ci/recipes"
}

function copy_bedrock_pipeline() {
  template_cp_dir "/bedrock/templates/pipelines/" "$(service_root)/.bedrock/ci/pipelines"
}

function install_service_pipeline() {
  printf '%s not defined' "${FUNCTION}"
}

function commit_changes_to_service() {
  printf '%s not defined' "${FUNCTION}"
}

function copy_templates_to_repo() {
  create_template_folders
  copy_dockerfile_if_needed
  copy_helm_chart_if_needed
  copy_semver_if_needed
  copy_bedrock_recipes
  copy_bedrock_pipeline
  install_service_pipeline
  commit_changes_to_service
}

function init_service_tree () {
  if [[ -z "$(service_name)" ]]; then
    printf 'Please provide name for this new service via the BEDROCK_SERVICE environment variable'
    false
  else
    copy_templates_to_repo
    commit_templates_to_repo
  fi
}

init_service_tree
