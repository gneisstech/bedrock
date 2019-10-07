#!/usr/bin/env bash
# usage: create_web_service_if_needed.sh web_service_name

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
declare -rx WEB_SERVICE_NAME="${1}"

function web_service_name (){
    echo "${WEB_SERVICE_NAME}"
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

function saas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function svc_attr () {
    local -r attr="${1}"
    saas_configuration | jq -r -e ".web_services.services[] | select(.name == \"$(web_service_name)\") | .${attr}"
}

function web_service_resource_group () {
    svc_attr 'resource_group'
}

function web_service_plan () {
    saas_configuration | jq -r -e ".web_services.farm"
}

function web_service_container_path () {
    echo "$(svc_attr 'container.registry')/$(svc_attr 'container.name'):$(svc_attr 'container.tag')"
}

function web_service_already_exists () {
    az webapp show \
        --name "$(web_service_name)" \
        --resource-group "$(web_service_resource_group)" \
        > /dev/null 2>&1
}

function deploy_web_service () {
    echo az webapp create \
        --name "$(web_service_name)" \
        --resource-group "$(web_service_resource_group)" \
        --plan "$(web_service_plan)" \
        --deployment-container-image-name "$(web_service_container_path)"
}

function create_web_service_if_needed () {
    web_service_already_exists || deploy_web_service
}

create_web_service_if_needed

