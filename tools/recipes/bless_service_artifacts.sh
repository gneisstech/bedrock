#!/usr/bin/env bash
# usage: bless_service_artifacts.sh

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
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function is_azure_pipeline_build() {
  [[ "True" == "${TF_BUILD:-}" ]]
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

function get_docker_registry() {
  get_docker_repo_name | sed -e 's|\/.*||'
}

function get_docker_registry_name() {
  get_docker_registry | sed -e 's|\..*||'
}

function get_helm_registry_name() {
  get_docker_registry_name
}

function update_helm_repo() {
  helm repo remove "$(get_helm_registry_name)" 2>/dev/null || true
  az acr helm repo add -n "$(get_helm_registry_name)"
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
  git describe --match "$(release_prefix_glob)" --abbrev=0 --first-parent 2>/dev/null || true
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
  printf 'semver.txt'
}

function internal_semver_file() {
  printf '%s/%s' "$(bedrock_app_semver_dir)" "$(bedrock_app_semver_filename)"
}

function internal_semver_file_json() {
  yq eval-all "$(internal_semver_file)" --tojson
}

function internal_repo_semver() {
  jq -r '.semver' <(internal_semver_file_json)
}

function compute_blessed_release_semver() {
  sort -t. -k 1,1nr -k 2,2nr -k 3,3nr <(new_repo_semver) <(internal_repo_semver) | head -1
}

function compute_blessed_release_tag() {
  local new_tag prerelease
  new_tag="$(compute_blessed_release_semver)"
  prerelease="dev"
  if ! is_azure_pipeline_build; then
    prerelease="${prerelease}.private"
  fi
  printf '%s%s-%s' "$(release_prefix)" "${new_tag}" "${prerelease}"
}

function update_git_config() {
  if is_azure_pipeline_build; then
    # configure azure pipeline workspace
    git config --global user.email "azure_automation@gneiss-tech.net"
    git config --global user.name "Azure automation Blessing Artifacts from [app-env)]"
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
  local -r blessed_release_semver="${1}"
  local -r temp_file="$(mktemp)"
  internal_semver_file_json |
    jq -r --arg new_semver "${blessed_release_semver}" '.semver = $new_semver' |
    yq eval-all - >"${temp_file}"
  cp "${temp_file}" "$(internal_semver_file)"
  rm -f "${temp_file}"
  git add "$(internal_semver_file)"
  if pending_git_files; then
    printf 'pushing git tag update [%s]\n' "$(cat "$(internal_semver_file)")"
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
  local -r blessed_release_tag="${1}"
  update_git_config
  update_internal_repo_semver "$(extract_semver <<<"${blessed_release_tag}")"
  update_git_tag "${blessed_release_tag}"
}

function registry_image_name() {
  local -r imageName="${1}"
  local -r tag="${2}"
  printf '%s/%s:%s' "$(get_docker_registry)" "${imageName}" "${tag}"
}

function acr_login() {
  local -r desired_repo="${1}"
  az acr login -n "${desired_repo}"
}

function desired_image_exists() {
  local -r imageName="${1}"
  local -r tag="${2}"
  printf 'desired_image_exists %s:%s\n' "${imageName}" "${tag}"
  acr_login "$(get_docker_registry_name)"
  docker pull "$(registry_image_name "${imageName}" "${tag}")" 2>/dev/null || return
}

function bless_container() {
  local -r imageName="${1}"
  local -r blessed_tag="${2}"
  local origin_container result_container
  origin_container="$(registry_image_name "${imageName}" "${TAG}")"
  result_container="$(registry_image_name "${imageName}" "${blessed_tag}")"
  docker tag "${origin_container}" "${result_container}" || return
  docker push "${result_container}" 1>&2 || return
}

function get_helm_chart_repositories() {
  read_helm_values_as_json | jq -cr '.[] | select(.repository?) | .repository'
}

function get_image_names() {
  get_helm_chart_repositories | sed -e 's|.*\/||'
}

function update_docker_containers() {
  local -r blessed_release_tag="${1}"
  local imageName
  for imageName in $(get_image_names); do
    printf 'update_docker_container %s:%s\n' "${imageName}" "${blessed_release_tag}"
    if ! desired_image_exists "${imageName}" "${blessed_release_tag}"; then
      bless_container "${imageName}" "${blessed_release_tag}" || return
    fi
  done
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

function build_and_push_helm_chart() {
  local -r chartDir="${1}"
  local -r blessed_release_tag="${2}"
  local chartPackage result
  chartPackage="$(get_helm_chart_name)-$(remove_release_prefix <<<"${blessed_release_tag}").tgz"
  rm -f "${chartDir}/Chart.lock"
  helm dependency build "${chartDir}" || return
  git add "${chartDir}/Chart.lock" || true
  helm package "${chartDir}" || return
  if az acr helm push -n "$(get_helm_registry_name)" "${chartPackage}" 2>/dev/null; then
    result=0
  else
    printf 'Race condition resolved in favor of earlier job\n'
    result=0
  fi
  rm -f "${chartPackage}"
  ((result == 0))
}

function chart_dir() {
  printf '/src/helm/%s/' "$(get_helm_chart_name)"
}

function update_helm_package() {
  local -r blessed_release_tag="${1}"
  printf 'update_helm_chart %s\n' "${blessed_release_tag}"
  local chartDir
  chartDir="$(chart_dir)"
  update_chart_yaml "${chartDir}" "${blessed_release_tag}"
  build_and_push_helm_chart "${chartDir}" "${blessed_release_tag}"
}

function warn_nothing_done() {
  printf 'Did not update docker container or helm chart\n'
  printf '  If this is not what you intended, did you update the semver.txt or git tag?\n'
}

function update_docker_helm_git() {
  local -r blessed_release_tag="$(compute_blessed_release_tag)"
  if update_docker_containers "${blessed_release_tag}"; then
    if update_helm_package "${blessed_release_tag}"; then
      bless_git_repo "${blessed_release_tag}"
    fi
  else
    warn_nothing_done
    false
  fi
}

function bless_service_artifacts() {
  internal_semver_file_json
  update_helm_repo
  update_docker_helm_git
}

bless_service_artifacts
