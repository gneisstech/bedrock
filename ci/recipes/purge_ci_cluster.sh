#!/usr/bin/env bash
# usage: purge_environment_cluster.sh

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

function purge_environment_cluster () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        "$(repo_root)/recipes/purge_environment_cluster.sh" "CF_CI"
    popd
}

purge_environment_cluster
