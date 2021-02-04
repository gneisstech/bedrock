#!/usr/bin/env bash
# usage: go_module_fetch_vendor_folder.sh

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

function go_module_fetch_vendor_folder () {
  git config --global --replace-all url.git+ssh://ablcode@vs-ssh.visualstudio.com/v3/ablcode.insteadof https://ablcode.visualstudio.com
  CGO_ENABLED=1 GO111MODULE=on GOPRIVATE=ablcode.visualstudio.com go mod vendor -v
}

go_module_fetch_vendor_folder || true
