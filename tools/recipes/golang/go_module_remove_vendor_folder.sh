#!/usr/bin/env bash
# usage: go_module_remove_vendor_folder.sh

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

function go_module_remove_vendor_folder () {
     rm -rf ./vendor
     rm ~/.gitconfig
}

go_module_remove_vendor_folder || true
