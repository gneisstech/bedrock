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
    az acr login -n cfprodregistry
}

function promote_containers () {
    local -r originRepo='cfqaregistry.azurecr.io'
    #local -r containers='cf-oauth-proxy-docker cf-react-app-docker cf-ruby-api-docker cf-self-healing-api-docker cf-self-healing-app-docker'
    local -r containers='cf-self-healing-api-docker cf-self-healing-app-docker'
    #local -r containers='cf-atrius-objects-api-docker cf-authz-web-api-docker cf-elm-web-api-docker cf-network-view-web-api-docker cf-oauth-proxy-docker cf-react-app-docker'
    #local -r containers='cf-oauth-proxy-docker'
    acr_logins
    for image in ${containers}; do
        local imageWithTag originPath targetPath targetRepo
        imageWithTag="${image}:connected-facilities"
        originPath="${originRepo}/${imageWithTag}"
        docker pull "${originPath}"
        #shellcheck disable=SC2043
        for targetRepo in cfprodregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${imageWithTag}"
            docker tag "${originPath}" "${targetPath}"
            docker push "${targetPath}"
        done
    done
}

promote_containers
