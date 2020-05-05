#!/usr/bin/env bash
# usage: prepare_containers_for_k8s.sh

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
    az acr login -n cfqaregistry
}

function acr_containers () {
    local -r repository="${1}"
    az acr repository  list --name "${repository}" | jq -r '. | @tsv'
}

function prepare_containers_for_k8s () {
    local -r originRepo='cfqaregistry'
    #local -r app_version='r0.0.20-IndividualCI.20200428.3.RC'
    local -r app_version='r0.0.22-Manual.20200504.2.RC'
    acr_logins
    for image in $(acr_containers "${originRepo}" ); do
        local originImage originPath targetPath targetRepo
        originImage="${image}:connected-facilities"
        originPath="${originRepo}.azurecr.io/${originImage}"
        docker pull "${originPath}"
        # shellcheck disable=SC2043
        for targetRepo in cfqaregistry; do
            local targetPath
            targetPath="${targetRepo}.azurecr.io/${image}:${app_version}"
            docker tag "${originPath}" "${targetPath}"
            docker push "${targetPath}"
        done
    done
}

prepare_containers_for_k8s
