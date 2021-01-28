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

declare -rx required_repo_branch="${required_repo_branch:-deployment_request/prod}"
declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-qa}"
declare -rx ORIGIN_SUBSCRIPTION="${ORIGIN_SUBSCRIPTION:-Bedrock-QA}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-brqaregistry}"
declare -rx ORIGIN_RESOURCE_PREFIX="${ORIGIN_RESOURCE_PREFIX:-br-qa-}"
declare -rx TARGET_REPOSITORY="${TARGET_REPOSITORY:-brprodregistry}"
declare -rx RELEASE_PREFIX='r'
declare -rx DEFAULT_RELEASE='r0.0.0'
declare -rx BUMP_SEMVER="false"
declare -rx RELEASE_CANDIDATE="false"

function repo_root () {
    git rev-parse --show-toplevel
}

function bless_qa_artifacts () {
    SECONDS=0
    "/bedrock/ci/recipes/bless_development_artifacts.sh"
    DD_CLIENT_API_KEY="${1:-}" DD_CLIENT_APP_KEY="${2:-}" "/bedrock/ci/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
}

bless_qa_artifacts "$@" 2> >(while read -r line; do (echo "STDERR: $line"); done)
