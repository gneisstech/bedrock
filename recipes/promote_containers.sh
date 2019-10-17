#!/usr/bin/env bash
# usage: promote_containers.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx TARGET_CONFIG

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function promote_containers () {
    local -r originRepo="atfcfexpdev.azurecr.io"
    local -r targetRepo="cfapspiceqaregistry.azurecr.io"
    local -r containers="cf-oauth-proxy-docker cf-react-app-docker cf-ruby-api-docker cf-self-healing-api-base cf-self-healing-api-docker cf-self-healing-app-docker"
    for image in ${containers}; do
      local imageWithTag originPath targetPath
      imageWithTag="${image}:connected-facilities"
      originPath="${originRepo}/${imageWithTag}"
      targetPath="${targetRepo}/${imageWithTag}"
      docker pull "${originPath}"
      docker tag "${originPath}" "${targetPath}"
      docker push "${targetPath}"
    done
}

set -x
promote_containers
