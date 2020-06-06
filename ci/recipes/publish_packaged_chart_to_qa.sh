#!/usr/bin/env bash
# usage: publish_packaged_chart_to_qa.sh

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

function publish_packaged_chart_to_qa () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        "$(repo_root)/recipes/publish_packaged_chart_to_env.sh" 'CF_QA'
    popd
}

publish_packaged_chart_to_qa 2> >(while read -r line; do (echo "STDERR: $line"); done)
