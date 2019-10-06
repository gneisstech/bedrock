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

function sast_shellcheck () {
    find "$(repo_root)" -name "*.sh" -print0 | xargs -0 -n 1 shellcheck --check-sourced
}

sast_shellcheck

