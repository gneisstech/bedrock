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
declare -rx AZ_TRACE

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
    svc_attr "${attr}" | jq -r -e ".${key} as \$config | \$config | [ keys[] | \"\(.)=\(\$config[.] | if type==\"array\" then join(\"\") else . end  )\" ] | @tsv"
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

function process_acr_registry_key () {
    local -r theString="${1}"
    local acr_name rg_name theMessage
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    acr_name="$(jq -r '.registry' <<< "${theMessage}")"
    rg_name="$(jq -r '.resource_group' <<< "${theMessage}")"
    az acr credential show --name "${acr_name}" --resource-group "${rg_name}" 2> /dev/null || echo "FIXME_PASSWORD"
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function set_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    local -r secret="${3}"
    az keyvault secret set \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        --description 'secure secret from deployment automation' \
        --value "${secret}" \
        2> /dev/null
}

function random_key () {
    hexdump -n 27 -e '"%02X"' /dev/urandom
}

function process_secure_secret () {
    local -r theString="${1}"
    local vault secret_name theMessage secret
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    vault="$(jq -r '.vault' <<< "${theMessage}")"
    secret_name="$(jq -r '.secret_name' <<< "${theMessage}")"
    secret="$(get_vault_secret "${vault}" "${secret_name}")"
    if [[ -z "${secret}" ]]; then
        set_vault_secret "${vault}" "${secret_name}" "$(random_key)" > /dev/null
        secret="$(get_vault_secret "${vault}" "${secret_name}")"
    fi
    if [[ -z "${secret}" ]]; then
        secret="FAKE_SECRET"
    fi
    echo "${secret}"
}

function dispatch_functions () {
    declare -a myarray
    (( i=0 ))
    while IFS=$'\n' read -r line_data; do
        local array_entry="${line_data}"
        if (( i % 2 == 1 )); then
            case "$line_data" in
                acr_registry_key*)
                    array_entry="$(process_acr_registry_key "${line_data}")"
                    ;;
                secure_secret*)
                    array_entry="$(process_secure_secret "${line_data}")"
                    ;;
                *)
                   array_entry="UNDEFINED_FUNCTION [${line_data}]"
                   ;;
            esac
        fi
        myarray[i]="${array_entry}"
        ((++i))
    done

    (( i=0 ))
    while (( ${#myarray[@]} > i )); do
        printf '%s' "${myarray[i++]}"
    done
}

function interpolate_functions () {
    awk '{gsub(/##/,"\n"); print}' | dispatch_functions
}

function prepare_connection_strings () {
    local type="${1}"
    svc_strings 'connection_strings' "${type}" | interpolate_functions
}

function connection_string_types () {
    svc_attr 'connection_strings' | jq -r -e 'keys | @tsv'
}

function set_connection_strings () {
    if [[ -n "$(svc_attr 'connection_strings')" ]]; then
        local i
        for i in $(connection_string_types); do
            $AZ_TRACE webapp config connection-string set \
                --name "$(service_name)" \
                --resource-group "$(service_resource_group)" \
                --connection-string-type "${i}" \
                --settings "$(prepare_connection_strings "${i}")"
        done
    fi
}

function container_settings_string () {
    local -r key="${1}"
    svc_string 'container_settings' "${key}" | interpolate_functions
}

function set_container_settings () {
    $AZ_TRACE webapp config container set \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --docker-custom-image-name "$(container_settings_string 'DOCKER_CUSTOM_IMAGE_NAME')" \
        --docker-registry-server-password "$(container_settings_string 'DOCKER_REGISTRY_SERVER_PASSWORD')" \
        --docker-registry-server-url "$(container_settings_string 'DOCKER_REGISTRY_SERVER_URL')" \
        --docker-registry-server-user "$(container_settings_string 'DOCKER_REGISTRY_SERVER_USERNAME')" \
        --enable-app-service-storage "$(container_settings_string 'WEBSITES_ENABLE_APP_SERVICE_STORAGE')"
}

function svc_appsettings () {
    svc_strings '' 'config' | interpolate_functions
}

function set_app_settings () {
    # shellcheck disable=SC2046
    $AZ_TRACE webapp config appsettings set \
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
    $AZ_TRACE acr webhook create \
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
    $AZ_TRACE webapp create \
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
