#!/usr/bin/env bash
# usage: update_service_dependencies.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BUILD_SOURCEBRANCH
declare -rx BUILD_SOURCEBRANCHNAME
declare -rx TF_BUILD

# Arguments
# ---------------------

declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-dev}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfdevregistry}"
declare -rx RELEASE_PREFIX="${RELEASE_PREFIX:-r}"
declare -rx DEFAULT_SEMVER="${DEFAULT_SEMVER:-0.0.0}"
declare -rx BUMP_SEMVER="${BUMP_SEMVER:-true}"
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"
declare -rx required_repo_branch="${required_repo_branch:-master-bytelight}"

function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function current_repo_branch () {
    local branch
    if is_azure_pipeline_build; then
        branch="${BUILD_SOURCEBRANCHNAME:-}"
    else
        branch="$(git rev-parse --abbrev-ref HEAD)"
    fi
    printf "%s" "${branch}"
}

function validate_branch () {
    git status
    printf 'branches: required [%s], current [%s], build_sourcebranch [%s]\n' \
        "${required_repo_branch}" \
        "$(current_repo_branch)" \
        "${BUILD_SOURCEBRANCH:-}"
    [[ "$(current_repo_branch)" == "${required_repo_branch}" ]] \
        || [[ "${BUILD_SOURCEBRANCH:-}" == "refs/heads/${required_repo_branch}" ]]
}

function services_changed_semver () {
    printf 'triggered build from [%s]' "${BUILD_SOURCEBRANCH:-}\n"
    env
    true
}

function update_service_dependencies () {
    if validate_branch; then
        if services_changed_semver; then
            $(repo_root)/ci/recipes/update_umbrella_chart.sh
        fi
    fi
}

update_service_dependencies
