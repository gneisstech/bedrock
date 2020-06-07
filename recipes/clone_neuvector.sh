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

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function acr_logins () {
    az acr login -n cfdevregistry
    az acr login -n cfqaregistry
    az acr login -n cfprodregistry
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
    docker login
    for image in ${containers}; do
        local originPath targetPath targetRepo
        originPath="${originRepo}${image}"
        docker pull "${originPath}"
        #shellcheck disable=SC2043
        for targetRepo in cfdevregistry cfqaregistry cfprodregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${image}"
            docker tag "${originPath}" "${targetPath}"
            docker push "${targetPath}"
        done
    done
}

clone_neuvector