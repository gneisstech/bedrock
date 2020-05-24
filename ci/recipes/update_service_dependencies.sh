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
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"

function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function git_repo_branch () {
    git rev-parse --abbrev-ref HEAD
}

function current_repo_branch () {
    local branch
    if is_azure_pipeline_build; then
        branch="${BUILD_SOURCEBRANCHNAME:-}"
    else
        branch="$(git_repo_branch)"
    fi
    printf "%s" "${branch}"
}

function trace_environment () {
    printf 'triggered build from [%s]' "${BUILD_SOURCEBRANCH:-}\n"
    git status
    printf 'branches: current [%s], build_sourcebranch [%s], git branch [%s]\n' \
        "$(current_repo_branch)" \
        "${BUILD_SOURCEBRANCH:-}" \
        "$(git_repo_branch)"
    env
}

#
# there are four basic cases to consider:
# chart.lock semver matches latest service semver => no change
# chart.lock semver does not match latest service semver => remove lock, rebuild umbrella [inspect service semver for new feature or breaking change, respond accordingly]
# chart.lock semver does not exist for service => remove lock, rebuild umbrella [ new feature change ]
# chart.lock semver exists, but no artifacts for service => remove lock, rebuild umbrella [breaking change]
#

function services_changed_semver () {
    true
}

function update_service_dependencies () {
    trace_environment
    if services_changed_semver; then
        $(repo_root)/ci/recipes/update_umbrella_chart.sh
    fi
}

update_service_dependencies
