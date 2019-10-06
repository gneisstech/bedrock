#!/usr/bin/env bash
# usage: create_container_registry_if_needed.sh container_registry_name

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
declare -rx CONTAINER_REGISTRY_NAME="${1}"

function container_registry_name (){
    echo "${CONTAINER_REGISTRY_NAME}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
    local -r layer="${1}"
    local -r target_recipe="${2}"
    shift 2
    "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function acr_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".container_registries[] | select(.name == \"$(container_registry_name)\") | .${attr}"
}

function container_registry_resource_group () {
    acr_attr 'resource_group'
}

function fail_empty_set () {
    grep -q '^'
}

function container_registry_already_exists () {
    az acr show \
        --name "$(container_registry_name)" \
        --resource-group "$(container_registry_resource_group)" \
        > /dev/null 2>&1
}

function deploy_container_registry () {
    echo az acr create \
        --name "$(container_registry_name)" \
        --resource-group "$(container_registry_resource_group)" \
        --sku "$(acr_attr 'sku')" \
        --admin-enabled  "$(acr_attr 'admin_enabled')"
}

function create_container_registry_if_needed () {
    container_registry_already_exists || deploy_container_registry
}

create_container_registry_if_needed
