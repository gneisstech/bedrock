#!/usr/bin/env bash
# usage: bless_qa_artifacts.sh

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

declare -rx required_repo_branch="${required_repo_branch:-deployment_request/staging}"
declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-qa}"
declare -rx ORIGIN_SUBSCRIPTION="${ORIGIN_SUBSCRIPTION:-ConnectedFacilities-QA}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfqaregistry}"
declare -rx ORIGIN_RESOURCE_PREFIX="${ORIGIN_RESOURCE_PREFIX:-cf-qa-}"
declare -rx TARGET_REPOSITORY="${TARGET_REPOSITORY:-cfstagingregistry}"
declare -rx RELEASE_PREFIX='r'
declare -rx DEFAULT_RELEASE='r0.0.0'
declare -rx BUMP_SEMVER="false"

function repo_root () {
    git rev-parse --show-toplevel
}

function bless_qa_artifacts () {
    exec "$(repo_root)/ci/recipes/bless_development_artifacts.sh"
}

bless_qa_artifacts
