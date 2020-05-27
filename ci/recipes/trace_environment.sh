#!/usr/bin/env bash
# usage: trace_environment.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BUILD_SOURCEBRANCHNAME="${BUILD_SOURCEBRANCHNAME:-}"
declare -rx TF_BUILD="${TF_BUILD:-}"

# Arguments
# ---------------------


function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function git_repo_branch () {
    git rev-parse --abbrev-ref 'HEAD'
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
    set -o xtrace
    helm version
    az version
    az account show
    yq --version
    jq --version
    bash --version
    command -V read || true
    command -V readline || true
    readline -v || true
    command -V readarray || true
    help

    printf '=========================== %s ============================\n' 'env follows'
    env
    printf '=========================== %s ============================\n' 'set follows'
    set
    set +o xtrace
}

trace_environment
