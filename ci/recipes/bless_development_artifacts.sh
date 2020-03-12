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

# Arguments
# ---------------------

declare -rx required_repo_branch="${required_repo_branch:-deployment_request/qa}"
declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-dev}"
declare -rx ORIGIN_SUBSCRIPTION="${ORIGIN_SUBSCRIPTION:-ConnectedFacilities-Dev}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfdevregistry}"
declare -rx ORIGIN_RESOURCE_PREFIX="${ORIGIN_RESOURCE_PREFIX:-cf-dev-}"
declare -rx TARGET_REPOSITORY="${TARGET_REPOSITORY:-cfqaregistry}"
declare -rx RELEASE_PREFIX="${RELEASE_PREFIX:-r}"
declare -rx DEFAULT_RELEASE="${DEFAULT_RELEASE:-r0.0.0}"
declare -rx BUMP_SEMVER="${BUMP_SEMVER:-true}"
declare -rx RELEASE_CANDIDATE="${RELEASE_CANDIDATE:-true}"

function repo_root () {
    git rev-parse --show-toplevel
}

function branch_tag () {
    git describe
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function acr_login () {
    local -r desired_repo="${1}"
    if ! is_azure_pipeline_build; then
        az acr login -n "${desired_repo}" 2> /dev/null
    fi
}

function current_repo_branch () {
    git status -b  | grep "^On branch" | sed -e 's/.* //'
}

function release_prefix () {
    printf '%s' "${RELEASE_PREFIX}"
}

function release_prefix_glob () {
    printf '%s*' "$(release_prefix)"
}

function release_prefix_remove_expr () {
    printf 's/^%s//' "$(release_prefix)"
}

function current_repo_version () {
    git describe --match "$(release_prefix_glob)" --abbrev=0
}

function current_repo_semver () {
    # see https://semver.org
    current_repo_version | cut -d '+' -f 1 | cut -d '-' -f 1 | sed -e "$(release_prefix_remove_expr)"
}

function current_repo_build () {
    # see https://semver.org
    current_repo_version | cut -d '+' -f 2 -s
}

function current_repo_prerelease () {
    # see https://semver.org
    current_repo_version | cut -d '+' -f 1 | cut -d '-' -f 2 -s
}

function default_repo_semver () {
    local current_semver
    current_semver="$(current_repo_semver)"
    if [[ -z "${current_semver:-}" ]]; then
        current_semver="${DEFAULT_RELEASE}"
    fi
    printf '%s' "${current_semver}"
}

function bump_repo_semver () {
    local current_semver="${1}"
    if [[ "true" == "${BUMP_SEMVER}" ]]; then
        local major minor patch
        major="$(printf '%s' "${current_semver}" | cut -d "." -f 1)"
        minor="$(printf '%s' "${current_semver}" | cut -d "." -f 2)"
        patch="$(printf '%s' "${current_semver}" | cut -d "." -f 3)"
        (( patch++ ))
        current_semver="${major}.${minor}.${patch}"
    fi
    printf '%s' "${current_semver}"
}

function new_repo_semver () {
    local current_semver
    current_semver="$( bump_repo_semver "$(default_repo_semver)" )"
    if [[ "true" == "${RELEASE_CANDIDATE}" ]]; then
        current_semver="${current_semver}-RC"
    else
        local current_prerelease="$(current_repo_prerelease)"
        if [[ -n "${current_prerelease:-}" ]]; then
            current_semver="${current_semver}-${current_prerelease}"
        fi
    fi
    if is_azure_pipeline_build; then
        current_semver="${current_semver}+${BUILD_REASON}@${BUILD_BUILDNUMBER}"
    else
        local current_build="$(current_repo_build)"
        if [[ -n "${current_build:-}" ]]; then
            current_semver="${current_semver}+${current_build}"
        fi
    fi
}

function origin_environment () {
    printf '%s' "${ORIGIN_ENVIRONMENT}"
}

function origin_subscription () {
    printf '%s' "${ORIGIN_SUBSCRIPTION}"
}

function origin_repository () {
    printf '%s' "${ORIGIN_REPOSITORY}"
}

function origin_resource_prefix () {
    printf '%s' "${ORIGIN_RESOURCE_PREFIX}"
}

function target_repository () {
    printf '%s' "${TARGET_REPOSITORY}"
}

function list_subscription_webapps () {
    local -r subscription="${1}"
    az webapp list --subscription "${subscription}" 2> /dev/null
}

function origin_deployment_ids () {
    local -r origin_resource_prefix="${1}"
    jq -r --arg prefix "${origin_resource_prefix}" '.[] | select (.name | test($prefix)) | .id'
}

function webapp_configs_from_ids () {
    xargs az webapp config show --ids 2> /dev/null
}

function container_images_from_webapp_config () {
    jq -r '.[] | .linuxFxVersion' | sed -e 's/^DOCKER|//'
}

function compute_blessed_release_tag () {
    local new_semver build prerelease
    new_semver="$(new_repo_semver)"
    printf '%s%s' "$(release_prefix)" "${new_semver}"
}

function list_deployed_containers () {
    list_subscription_webapps "$(origin_subscription)" \
        | origin_deployment_ids "$(origin_resource_prefix)" \
        | webapp_configs_from_ids \
        | container_images_from_webapp_config
}

function target_path_with_new_tag () {
    local -r new_tag="${1}"
    sed -e 's/:.*//' \
        -e "s/$/:${new_tag}/" \
        -e "s:^[^/]*/\(.*\):$(target_repository).azurecr.io/\1:"
}

function bless_container () {
    local -r container_path="${1}"
    local -r blessed_semver="${2}"
    local blessed_path
    blessed_path="$(printf '%s' "${container_path}" | target_path_with_new_tag "${blessed_semver}" )"
    deployment_path="$(printf '%s' "${container_path}" | target_path_with_new_tag 'connected-facilities' )"
    docker pull "${container_path}"
    docker tag "${container_path}" "${blessed_path}"
    docker tag "${container_path}" "${deployment_path}"
    printf '%s blessed %s\n' "${container_path}" "${blessed_path}"
    docker push "${blessed_path}"
    printf '%s deploy_to %s\n' "${container_path}" "${deployment_path}"
    docker push "${deployment_path}"
}

function bless_git_repo () {
    if is_azure_pipeline_build; then
        # configure azure pipeline workspace
        git config --global user.email "azure_automation@bytelight.com"
        git config --global user.name "Azure automation Blessing Artifacts from [$(origin_environment)]"
    fi
    if [[ "true" == "${BUMP_SEMVER}" ]]; then
        git tag -a "${blessed_release_tag}" -m "automated promotion on git commit"
        git push origin "${blessed_release_tag}"
    fi
}

function bless_deployed_containers () {
    local container_path
    local -r blessed_release_tag="$(compute_blessed_release_tag)"
    acr_login "$(origin_repository)"
    acr_login "$(target_repository)"
    for container_path in $(list_deployed_containers); do
        bless_container "${container_path}" "${blessed_release_tag}"
        docker inspect "${container_path}"
    done
    bless_git_repo
}

function pull_deployment_into_local_containers () {
    harvest_deployed_containers
}

function is_merge () {
    git show --summary HEAD | grep -q '^Merge:' 
}

function validate_branch () {
    [[ "$(current_repo_branch)" == "${required_repo_branch}" ]] \
        || [[ "${BUILD_SOURCEBRANCH:-}" == "refs/heads/${required_repo_branch}" ]]
}

function bless_development_artifacts () {
    if validate_branch; then
        bless_deployed_containers
    fi
}

bless_development_artifacts
