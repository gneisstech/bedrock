#!/usr/bin/env bash
# usage: update_helm_chart.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx RELEASE_PREFIX="${RELEASE_PREFIX:-r}"
declare -rx DEFAULT_SEMVER="${DEFAULT_SEMVER:-0.0.0}"
declare -rx BUMP_SEMVER="${BUMP_SEMVER:-true}"
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"
declare -rx TAG="${TAG:-bedrock}"
declare -rx BUILD_SOURCEBRANCH
declare -rx TF_BUILD
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function is_azure_pipeline_build() {
  [[ "True" == "${TF_BUILD:-}" ]]
}

function get_deployment_json_by_name() {
  local -r deployment_name="${1}"
  "/bedrock/recipes/get_deployment_json_by_name.sh" "${deployment_name}"
}

function update_helm_repo() {
  local -r deployment_json="${1}"
  helm repo remove "$(get_helm_registry "${deployment_json}")" 2>/dev/null || true
  az acr helm repo add -n "$(get_helm_registry "${deployment_json}")"
  helm repo update
  helm version
}

function current_repo_branch() {
  git status -b | grep "^On branch" | sed -e 's/.* //'
}

function release_prefix() {
  printf '%s' "${RELEASE_PREFIX}"
}

function release_prefix_glob() {
  printf '%s*' "$(release_prefix)"
}

function release_prefix_remove_expr() {
  printf 's/^%s//' "$(release_prefix)"
}

function current_repo_version() {
  git describe --match "$(release_prefix_glob)" --abbrev=0 2>/dev/null || true
}

function remove_release_prefix() {
  sed -e "$(release_prefix_remove_expr)"
}

function extract_semver() {
  cut -d '+' -f 1 | cut -d '-' -f 1 | remove_release_prefix
}

function extract_semver_major() {
  cut -d '.' -f 1
}

function extract_semver_minor() {
  cut -d '.' -f 2
}

function extract_semver_patch() {
  cut -d '.' -f 3
}

function extract_semver_build() {
  cut -d '+' -f 2 -s
}

function extract_semver_prerelease() {
  cut -d '+' -f 1 | cut -d '-' -f 2 -s
}

function current_repo_semver() {
  # see https://semver.org
  current_repo_version | extract_semver
}

function current_repo_build() {
  # see https://semver.org
  current_repo_version | extract_semver_build
}

function current_repo_prerelease() {
  # see https://semver.org
  current_repo_version | extract_semver_prerelease
}

function default_repo_semver() {
  local current_semver
  current_semver="$(current_repo_semver)"
  if [[ -z "${current_semver:-}" ]]; then
    current_semver="${DEFAULT_SEMVER}"
  fi
  printf '%s' "${current_semver}"
}

function bump_repo_semver() {
  local current_semver="${1}"
  if [[ "true" == "${BUMP_SEMVER}" ]]; then
    local major minor patch
    major="$(extract_semver_major <<<"${current_semver}")"
    minor="$(extract_semver_minor <<<"${current_semver}")"
    patch="$(extract_semver_patch <<<"${current_semver}")"
    ((patch++))
    current_semver="${major}.${minor}.${patch}"
  fi
  printf '%s' "${current_semver}"
}

function new_repo_semver() {
  local current_semver
  current_semver="$(bump_repo_semver "$(default_repo_semver)")"
  printf '%s' "${current_semver}"
}

function bedrock_app_semver_dir() {
  printf '%s' "${BEDROCK_INVOKED_DIR}"
}

function bedrock_app_semver_filename() {
  local -r deployment_json="${1}"
  jq -r -e '.environment.semver' <<<"${deployment_json}"
}

function bedrock_config_dir() {
  printf '%s/configuration' "${BEDROCK_INVOKED_DIR}"
}

function internal_semver_file() {
  local -r deployment_json="${1}"
  printf '%s/%s' "$(bedrock_app_semver_dir)" "$(bedrock_app_semver_filename "${deployment_json}")"
}

function internal_semver_file_json() {
  local -r deployment_json="${1}"
  yq r "$(internal_semver_file "${deployment_json}")" --tojson
}

function internal_repo_semver() {
  local -r deployment_json="${1}"
  jq -r '.semver' <(internal_semver_file_json "${deployment_json}")
}

function compute_blessed_release_semver() {
  local -r deployment_json="${1}"
  sort -t. -k 1,1nr -k 2,2nr -k 3,3nr <(new_repo_semver) <(internal_repo_semver "${deployment_json}") | head -1
}

function compute_blessed_release_tag() {
  local -r deployment_json="${1}"
  local new_tag prerelease
  new_tag="$(compute_blessed_release_semver "${deployment_json}")"
  prerelease="dev"
  if ! is_azure_pipeline_build; then
    prerelease="${prerelease}.private"
  fi
  printf '%s%s-%s' "$(release_prefix)" "${new_tag}" "${prerelease}"
}

function get_app() {
  local -r deployment_json="${1}"
  jq -r -e '.environment.app' <<<"${deployment_json}"
}

function get_env() {
  local -r deployment_json="${1}"
  jq -r -e '.environment.name' <<<"${deployment_json}"
}

function get_helm_registry() {
  local -r deployment_json="${1}"
  jq -r '.helm.umbrella.registry.name? // ""' <<<"${deployment_json}"
}

function get_app_env() {
  local -r deployment_json="${1}"
  printf '%s-%s' "$(get_app "${deployment_json}")" "$(get_env "${deployment_json}")"
}

function update_git_config() {
  local -r deployment_json="${1}"
  if is_azure_pipeline_build; then
    # configure azure pipeline workspace
    git config --global user.email "azure_automation@gneiss-tech.net"
    git config --global user.name "Azure automation Blessing Artifacts from [$(get_app_env "${deployment_json}")]"
  fi
}

function current_branch() {
  local branch
  if is_azure_pipeline_build; then
    branch="${BUILD_SOURCEBRANCH}"
  else
    branch="$(git rev-parse --abbrev-ref HEAD)"
  fi
  printf "%s" "${branch}"
}

function pending_git_files() {
  git status -s | grep -q '^M'
}

function update_internal_repo_semver() {
  local -r deployment_json="${1}"
  local -r blessed_release_semver="${2}"
  local -r temp_file="$(mktemp)"
  internal_semver_file_json "${deployment_json}"|
    jq -r --arg new_semver "${blessed_release_semver}" '.semver = $new_semver' |
    yq r - >"${temp_file}"
  cp "${temp_file}" "$(internal_semver_file "${deployment_json}" )"
  rm -f "${temp_file}"
  git add "$(internal_semver_file "${deployment_json}" )"
  if pending_git_files; then
    printf 'pushing git tag update [%s]\n' "$(cat "$(internal_semver_file "${deployment_json}" )")"
    git commit -m "automated update of semver on git commit" || true
    git push origin HEAD:"$(current_branch)"
  fi
}

function update_git_tag() {
  local -r blessed_release_tag="${1}"
  if [[ "true" == "${BUMP_SEMVER}" ]]; then
    printf 'pushing git commits: \n'
    git status
    git tag -a "${blessed_release_tag}" -m "automated promotion on git commit" 'HEAD'
    git push origin "${blessed_release_tag}"
  fi
}

function bless_git_repo() {
  local -r deployment_json="${1}"
  local -r blessed_release_tag="${2}"
  update_git_config "${deployment_json}"
  update_internal_repo_semver "${deployment_json}" "$(extract_semver <<<"${blessed_release_tag}")"
  update_git_tag "${blessed_release_tag}"
}

function update_chart_yaml() {
  local -r chartDir="${1}"
  local -r blessed_release_tag="${2}"
  local chartFile
  local -r temp_file="$(mktemp)"
  chartFile="${chartDir}/Chart.yaml"
  sed -e "s|^appVersion:.*|appVersion: '${blessed_release_tag}'|" \
    -e "s|^version:.*|version: $(remove_release_prefix <<<"${blessed_release_tag}")|" \
    "${chartFile}" \
    >"${temp_file}"
  cp "${temp_file}" "${chartFile}"
  rm "${temp_file}"
  git add "${chartFile}"
}

function get_helm_chart_name() {
  local -r deployment_json="${1}"
  jq -r -e '.helm.umbrella.name' <<<"${deployment_json}"
}

function build_and_push_helm_chart() {
  local -r deployment_json="${1}"
  local -r chartDir="${2}"
  local -r blessed_release_tag="${3}"
  local chartPackage result
  chartPackage="$(get_helm_chart_name "${deployment_json}")-$(remove_release_prefix <<<"${blessed_release_tag}").tgz"
  rm -f "${chartDir}/Chart.lock"
  helm dependency build "${chartDir}"
  git add "${chartDir}/Chart.lock" || true
  helm package "${chartDir}"
  if az acr helm push -n "$(get_helm_registry "${deployment_json}")" "${chartPackage}" 2>/dev/null; then
    result=0
  else
    printf 'Race condition resolved in favor of earlier job\n'
    result=1
  fi
  rm -f "${chartPackage}"
  ((result == 0))
}

function chart_dir() {
  local -r deployment_json="${1}"
  printf '%s/k8s/charts/%s/' "$(bedrock_config_dir)" "$(get_helm_chart_name "${deployment_json}")"
}

function update_helm_package() {
  local -r deployment_json="${1}"
  local -r blessed_release_tag="${2}"
  printf 'update_helm_chart %s\n' "${blessed_release_tag}"
  local chartDir
  chartDir="$(chart_dir "${deployment_json}")"
  update_chart_yaml "${chartDir}" "${blessed_release_tag}"
  build_and_push_helm_chart "${deployment_json}" "${chartDir}" "${blessed_release_tag}"
}

function update_helm_git() {
  local -r deployment_json="${1}"
  local -r blessed_release_tag="$(compute_blessed_release_tag "${deployment_json}")"
  if update_helm_package "${deployment_json}" "${blessed_release_tag}"; then
    bless_git_repo "${deployment_json}" "${blessed_release_tag}"
  fi
}

function update_helm_chart() {
  local -r target_deployment_name="${1}"
  local target_deployment_json
  target_deployment_json="$(get_deployment_json_by_name "${target_deployment_name}")"
  internal_semver_file_json "${target_deployment_json}"
  update_helm_repo "${target_deployment_json}"
  update_helm_git "${target_deployment_json}"
}

update_helm_chart "$@"
