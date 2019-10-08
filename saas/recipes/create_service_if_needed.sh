#!/usr/bin/env bash
# usage: create_service_if_needed.sh service_name

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
declare -rx SERVICE_NAME="${1}"
declare -rx SERVICE_GROUP="${2}"

function service_name (){
    echo "${SERVICE_NAME}"
}

function service_group (){
    echo "${SERVICE_GROUP}"
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
    saas_configuration | jq -r -e ".${SERVICE_GROUP}.services[] | select(.name == \"$(service_name)\") | .${attr} // empty"
}

function svc_string () {
    local -r attr="${1}"
    local -r key="${2}"
    svc_attr "${attr}" | jq -r -e ".${key} | if type==\"array\" then join(\"\") else . end"
}

function svc_strings () {
    local -r attr="${1}"
    local -r key="${2}"
    svc_attr "${attr}" | jq -r -e ".${key}[] | if type==\"array\" then join(\"\") else . end"
}

function service_resource_group () {
    svc_attr 'resource_group'
}

function service_plan () {
    saas_configuration | jq -r -e ".${SERVICE_GROUP}.farm"
}

function service_container_path () {
    echo "$(svc_attr 'container.registry')/$(svc_attr 'container.name'):$(svc_attr 'container.tag')"
}

function get_db_password () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    echo "fixme010"
}

function prepare_connection_strings () {
    local type="${1}"
    svc_strings 'connection_strings' "${type}"
}

function connection_string_types () {
    svc_attr 'connection_strings' | jq -r -e 'keys | @tsv'
}

function set_connection_strings () {
    if [[ -n "$(svc_attr 'connection_strings')" ]]; then
        local i
        for i in $(connection_string_types); do
            echo az webapp config connection-string set \
                --name "$(service_name)" \
                --resource-group "$(service_resource_group)" \
                --connection-string-type "${i}" \
                --settings "$(prepare_connection_strings "${i}")"
        done
    fi
}

function svc_appsettings () {
    svc_attr 'config' | jq -r '. as $config | keys[] | "\(.)=\($config[.])"'
}

function set_container_settings () {
    echo az webapp config container set \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --docker-custom-image-name "$(svc_string 'container_settings' 'DOCKER_CUSTOM_IMAGE_NAME')" \
        --docker-registry-server-password "$(svc_string 'container_settings' 'DOCKER_REGISTRY_SERVER_PASSWORD')" \
        --docker-registry-server-url "$(svc_string 'container_settings' 'DOCKER_REGISTRY_SERVER_URL')" \
        --docker-registry-server-user "$(svc_string 'container_settings' 'DOCKER_REGISTRY_SERVER_USERNAME')" \
        --enable-app-service-storage "$(svc_string 'container_settings' 'WEBSITES_ENABLE_APP_SERVICE_STORAGE')"
}

function set_app_settings () {
    # shellcheck disable=SC2046
    echo az webapp config appsettings set \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --settings $(svc_appsettings)
}

function webhook_actions () {
    svc_attr 'acr_webhook.actions' | jq -r -e '@tsv'
}

function webhook_uri () {
    az webapp deployment container show-cd-url \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        2> /dev/null \
    | jq -r -e '.CI_CD_URL // "unavailable"'
}

function set_webhook () {
    # shellcheck disable=SC2046
    echo az acr webhook create \
        --name "$(svc_attr 'acr_webhook.name')" \
        --resource-group "$(service_resource_group)" \
        --registry "$(svc_attr 'acr_webhook.registry')" \
        --scope "$(svc_attr 'container.name'):$(svc_attr 'container.tag')" \
        --status "$(svc_attr 'acr_webhook.status')" \
        --actions $(webhook_actions) \
        --uri "$(webhook_uri)"
}

function service_already_exists () {
    az webapp show \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        > /dev/null 2>&1
}

function deploy_service () {
    echo az webapp create \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --plan "$(service_plan)" \
        --deployment-container-image-name "$(service_container_path)"
    set_connection_strings
    set_container_settings
    set_app_settings
    set_webhook
}

function create_service_if_needed () {
    service_already_exists || deploy_service
}

create_service_if_needed

