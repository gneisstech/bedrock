#!/usr/bin/env bash
# usage: promote_dev_to_qa_k8s.sh

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

function promote_dev_to_qa_k8s () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        "$(repo_root)/recipes/promote_k8s_from_env_to_env.sh" 'CF_Development' 'CF_CI'
    popd
}

promote_dev_to_qa_k8s 2> >(while read -r line; do (echo "STDERR: $line"); done)
