#!/usr/bin/env bash

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

function excluded_paths () {
    echo -n "-path /*/saas/vf-saas-umbrella"
    echo -n " -o "
    echo -n "-path /*/saas/services/*/charts"
}

function find_yaml () {
    # shellcheck disable=SC2046
    find "$(repo_root)" \( $(excluded_paths) \) -prune -o -name "*.yaml" -print0
}

function sast_shellcheck () {
    find_yaml | xargs -0 -n 1 yamllint --strict --format colored
}

sast_shellcheck
