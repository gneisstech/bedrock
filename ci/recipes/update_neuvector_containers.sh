#!/usr/bin/env bash
# usage: update_neuvector_containers.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
# Environment Variables
# ---------------------
declare -rx DOCKER_TOKEN
declare -rx DOCKER_USER

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function update_neuvector () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        SECONDS=0
        "/bedrock/paas/recipes/clone_neuvector_containers.sh"
        DD_CLIENT_API_KEY="${1:-}" DD_CLIENT_APP_KEY="${2:-}" "/bedrock/ci/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
    popd
}

update_neuvector "$@" 2> >(while read -r line; do (echo "STDERR: $line"); done)
