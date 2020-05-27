#!/usr/bin/env bash
# usage: check_key_vault_access.sh

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

function check_key_vault_access () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        "$(repo_root)/recipes/check_key_vault_access.sh" "CF_Development"
    popd
}

check_key_vault_access
