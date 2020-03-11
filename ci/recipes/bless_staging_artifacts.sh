#!/usr/bin/env bash
# usage: bless_staging_artifacts.sh

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

declare -rx required_repo_branch="${required_repo_branch:-deployment_request/prod}"
declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-staging}"
declare -rx ORIGIN_SUBSCRIPTION="${ORIGIN_SUBSCRIPTION:-ConnectedFacilities-Prod}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfstagingregistry}"
declare -rx ORIGIN_RESOURCE_PREFIX="${ORIGIN_RESOURCE_PREFIX:-cf-staging-}"
declare -rx TARGET_REPOSITORY="${TARGET_REPOSITORY:-cfprodregistry}"
declare -rx RELEASE_PREFIX='r'
declare -rx DEFAULT_RELEASE='r0.0.0'
declare -rx BUMP_SEMVER="false"
declare -rx RELEASE_CANDIDATE="false"

function repo_root () {
    git rev-parse --show-toplevel
}

function bless_staging_artifacts () {
    exec "$(repo_root)/ci/recipes/bless_development_artifacts.sh"
}

bless_staging_artifacts
