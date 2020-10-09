#!/usr/bin/env bash
# usage: clone_neuvector.sh
# place copy of containers in our Azure repo(s) for reliability in pull

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx DOCKER_TOKEN
declare -rx DOCKER_USER

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function acr_logins () {
    az acr login -n cfdevregistry
    az acr login -n cfqaregistry
    az acr login -n cfprodregistry
    az acr login -n acuitygitlabregistry
}

function neuvector_containers () {
    grep 'repository:' "$(repo_root)/configuration/k8s/charts/neuvector-helm/values.yaml" | sed -e 's|.* ||'
}

function clone_neuvector () {
    local -r originRepo=''
    local containers
    containers="$(neuvector_containers)"
    printf 'containers [%s]\n' "${containers}"
    acr_logins
    echo "${DOCKER_TOKEN}" | docker login --username "${DOCKER_USER}" --password-stdin
    for image in ${containers}; do
        local originPath targetPath targetRepo
        originPath="${originRepo}${image}"
        docker pull "${originPath}"
        #shellcheck disable=SC2043
        for targetRepo in cfdevregistry cfqaregistry cfprodregistry acuitygitlabregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${image}"
            docker tag "${originPath}" "${targetPath}"
            docker push "${targetPath}"
        done
    done
}

clone_neuvector
