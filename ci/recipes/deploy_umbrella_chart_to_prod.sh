#!/usr/bin/env bash
# usage: deploy_umbrella_chart_to_prod.sh

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

function deploy_umbrella_chart_to_prod () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        "$(repo_root)/recipes/deployment_helm_update.sh" "CF_Prod"
    popd
}

deploy_umbrella_chart_to_prod 2> >(while read -r line; do (echo "STDERR: $line"); done)
