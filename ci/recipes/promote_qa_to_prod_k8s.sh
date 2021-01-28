#!/usr/bin/env bash
# usage: promote_qa_to_prod_k8s.sh

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

function repo_root () {
    git rev-parse --show-toplevel
}

function promote_qa_to_prod_k8s () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        SECONDS=0
        "/bedrock/recipes/promote_k8s_from_env_to_env.sh" 'BR_QA' 'BR_Prod'
        DD_CLIENT_API_KEY="${1:-}" DD_CLIENT_APP_KEY="${2:-}" "/bedrock/ci/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
    popd
}

promote_qa_to_prod_k8s "$@" 2> >(while read -r line; do (echo "STDERR: $line"); done)
