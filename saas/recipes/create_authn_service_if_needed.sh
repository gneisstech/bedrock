#!/usr/bin/env bash
# usage: create_authn_service_if_needed.sh authn_service_name

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
declare -rx AUTHN_SERVICE_NAME="${1}"

function authn_service_name (){
    echo "${AUTHN_SERVICE_NAME}"
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
    saas_configuration | jq -r -e ".authn_services.services[] | select(.name == \"$(authn_service_name)\") | .${attr}"
}

function authn_service_resource_group () {
    svc_attr 'resource_group'
}

function authn_service_plan () {
    saas_configuration | jq -r -e ".authn_services.farm"
}

function authn_service_container_path () {
    echo "$(svc_attr 'container.registry')/$(svc_attr 'container.name'):$(svc_attr 'container.tag')"
}

function get_db_password () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    echo "fixme010"
}

function prepare_connection_string () {
    local theString
    theString="$(svc_attr 'connection_strings.name')"
    theString="${theString}=sqlserver://"
    theString="${theString}$(svc_attr 'connection_strings.db_user')"
    theString="${theString}:"
    theString="${theString}$( \
        get_db_password \
        "$(svc_attr 'connection_strings.db_password.vault')" \
        "$(svc_attr 'connection_strings.db_password.secret_name')" \
    )"
    theString="${theString}@"
    theString="${theString}$(svc_attr 'connection_strings.server')"
    theString="${theString}:"
    theString="${theString}$(svc_attr 'connection_strings.port')"
    theString="${theString}/"
    theString="${theString}$(svc_attr 'connection_strings.schema')"
}

function count_connection_strings () {
    svc_attr 'connection_strings' | jq -r -e 'length // 0'
}

function set_connection_strings () {
    local i
    for i in $(seq 0 $(count_connection_strings)); do
        if [[ "SQLServer" == "$(svc_attr "connection_strings[${i}].type")" ]]; then
            echo az webapp config connection-string set \
                --name "$(authn_service_name)" \
                --resource-group "$(authn_service_resource_group)" \
                --connection-string-type "$(svc_attr "connection_strings[${i}].type")" \
                --settings "$(prepare_connection_string "${i}")"
        fi
    done
}

function svc_appsettings () {
    svc_attr 'config' | jq -r '. as $config | keys[] | "\(.)=\($config[.])"'
}

function set_container_settings () {
    echo az webapp config container set \
        --name "$(authn_service_name)" \
        --resource-group "$(authn_service_resource_group)" \
        --docker-custom-image-name "$(svc_attr 'container_settings.DOCKER_CUSTOM_IMAGE_NAME')" \
        --docker-registry-server-password "$(svc_attr 'container_settings.DOCKER_REGISTRY_SERVER_PASSWORD')" \
        --docker-registry-server-url "$(svc_attr 'container_settings.DOCKER_REGISTRY_SERVER_URL')" \
        --docker-registry-server-user "$(svc_attr 'container_settings.DOCKER_REGISTRY_SERVER_USERNAME')" \
        --enable-app-service-storage "$(svc_attr 'container_settings.WEBSITES_ENABLE_APP_SERVICE_STORAGE')"
}

function set_app_settings () {
    # shellcheck disable=SC2046
    echo az webapp config appsettings set \
        --name "$(authn_service_name)" \
        --resource-group "$(authn_service_resource_group)" \
        --settings $(svc_appsettings)
}

function set_webhook () {
cat > /dev/null <<END001
# Command
#     az acr webhook create : Create a webhook for an Azure Container Registry.
# 
# Arguments
#     --actions     [Required] : Space-separated list of actions that trigger the webhook to post
#                                notifications.  Allowed values: chart_delete, chart_push, delete,
#                                push, quarantine.
#     --name -n     [Required] : The name of the webhook.
#     --registry -r [Required] : The name of the container registry. You can configure the default
#                                registry name using az configure --defaults acr=<registry name>.
#     --uri         [Required] : The service URI for the webhook to post notifications.
#     --headers                : Space-separated custom headers in 'key[=value]' format that will be
#                                added to the webhook notifications. Use '' to clear existing headers.
#     --location -l            : Location. Values from: az account list-locations. You can configure
#                                the default location using az configure --defaults
#                                location=<location>.
#     --resource-group -g      : Name of resource group. You can configure the default group using az
#                                configure --defaults group=<name>.
#     --scope                  : The scope of repositories where the event can be triggered. For
#                                example, 'foo:*' means events for all tags under repository 'foo'.
#                                'foo:bar' means events for 'foo:bar' only. 'foo' is equivalent to
#                                'foo:latest'. Empty means events for all repositories.
#     --status                 : Indicates whether the webhook is enabled.  Allowed values: disabled,
#                                enabled.  Default: enabled.
#     --tags                   : Space-separated tags in 'key[=value]' format. Use '' to clear
#                                existing tags.
END001
}

function authn_service_already_exists () {
    az webapp show \
        --name "$(authn_service_name)" \
        --resource-group "$(authn_service_resource_group)" \
        > /dev/null 2>&1
}

function deploy_authn_service () {
    echo az webapp create \
        --name "$(authn_service_name)" \
        --resource-group "$(authn_service_resource_group)" \
        --plan "$(authn_service_plan)" \
        --deployment-container-image-name "$(authn_service_container_path)"
    set_connection_strings
    set_container_settings
    set_app_settings
    set_webhook
}

function create_authn_service_if_needed () {
    authn_service_already_exists || deploy_authn_service
}

create_authn_service_if_needed

