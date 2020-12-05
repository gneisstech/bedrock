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
    az acr login -n brdevregistry
    az acr login -n brqaregistry
    az acr login -n brprodregistry
}

function promote_containers () {
    local -r originRepo='brqaregistry.azurecr.io'
    #local -r containers='br-oauth-proxy-docker br-react-app-docker br-ruby-api-docker br-self-healing-api-docker br-self-healing-app-docker'
    local -r containers='br-self-healing-api-docker br-self-healing-app-docker'
    #local -r containers='br-atrius-objects-api-docker br-authz-web-api-docker br-elm-web-api-docker br-network-view-web-api-docker br-oauth-proxy-docker br-react-app-docker'
    #local -r containers='br-oauth-proxy-docker'
    acr_logins
    for image in ${containers}; do
        local imageWithTag originPath targetPath targetRepo
        imageWithTag="${image}:bedrock"
        originPath="${originRepo}/${imageWithTag}"
        docker pull "${originPath}"
        #shellcheck disable=SC2043
        for targetRepo in brprodregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${imageWithTag}"
            docker tag "${originPath}" "${targetPath}"
            docker push "${targetPath}"
        done
    done
}

promote_containers
