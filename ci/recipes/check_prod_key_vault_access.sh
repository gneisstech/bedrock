#!/usr/bin/env bash
# usage: check_prod_key_vault_access.sh

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

function check_prod_key_vault_access () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        SECONDS=0
        "$(repo_root)/recipes/check_key_vault_access.sh" "CF_Prod"
        DD_CLIENT_API_KEY=$1 DD_CLIENT_APP_KEY=$2 "$(repo_root)/ci/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
    popd
}

check_prod_key_vault_access "$@" 2> >(while read -r line; do (echo "STDERR: $line"); done)
