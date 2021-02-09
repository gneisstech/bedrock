#!/usr/bin/env bash
# usage: clean_subscription_resources.sh
#
# the intent of this script is to remove all non-persistent resources from a subscription
#

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -r CLEAN_SUBSCRIPTION="${CLEAN_SUBSCRIPTION:-Bedrock-Dev}"
declare -r CLEAN_RESOURCE_GROUPS_SUFFIX="${CLEAN_RESOURCE_GROUPS_SUFFIX:--exp-brdev}"
declare -r APPROVED="${APPROVED:-false}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function cleaningSubscription () {
    printf "%s" "${CLEAN_SUBSCRIPTION}"
}

function cleaningGroupsSuffix () {
    printf "%s" "${CLEAN_RESOURCE_GROUPS_SUFFIX}"
}

function get_resource_ids_for_groups () {
    local -r groupSuffix="$(cleaningGroupsSuffix)"
    az resource list --subscription "$(cleaningSubscription)" | jq -r '.[].id' | grep -i -- "${groupSuffix}\/"
}

function remove_persistent_resources () {
    grep -E -vi 'Microsoft.KeyVault|Microsoft.Sql|publicIPAddresses|Microsoft.Storage|\/ingestion|\/Acr-'
}

function clean_resource_ids () {
    if [[ "true" == "${APPROVED}" ]]; then
        xargs -P 32 -r az resource delete --ids
    else
        xargs -n 1 -r echo "removal candidate: "
    fi
}

function clean_subscription_resources () {
   get_resource_ids_for_groups | remove_persistent_resources | tee /dev/stderr | clean_resource_ids
}

clean_subscription_resources
