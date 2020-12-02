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

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function acr_logins () {
    az acr login -n cfdevregistry
    az acr login -n cfstagingregistry
    az acr login -n cfqaregistry
}

function verify_containers () {
    local -r containers='br-oauth-proxy-docker cf-react-app-docker cf-ruby-api-docker cf-self-healing-api-docker cf-self-healing-app-docker'
    acr_logins
    for image in ${containers}; do
        local imageWithTag targetPath targetRepo
        imageWithTag="${image}:connected-facilities"
        for targetRepo in cfdevregistry cfstagingregistry cfqaregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${imageWithTag}"
            docker pull "${targetPath}"
        done
    done
}

verify_containers
