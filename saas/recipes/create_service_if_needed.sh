#!/usr/bin/env bash
# usage: create_service_if_needed.sh service_name

#
# Maintainer: techguru@byiq.com
#
# Copyright (c) 2017-2019,  Cloud Scaling -- All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

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

function svc_attr_size () {
    local -r attr="${1}"
    saas_configuration | jq -r -e ".${SERVICE_GROUP}.services[] | select(.name == \"$(service_name)\") | .${attr} | length // 0"
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
    az acr credential show \
        --name "${acr_name}" \
        --resource-group "${rg_name}" \
        2> /dev/null \
    | jq -r -e '.passwords[0].value' \
    || echo "FIXME_PASSWORD"
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
    hexdump -n 16 -e '"%02X"' /dev/urandom
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

function enable_container_continuous_deployment () {
    $AZ_TRACE webapp deployment container config \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --enable-cd
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
    | jq -r -e '.CI_CD_URL // "https://unavailable"'
}

function set_webhook () {
    if [[ '0' != "$(svc_attr_size 'acr_webhook')" ]]; then
        # shellcheck disable=SC2046
        $AZ_TRACE acr webhook create \
            --name "$(svc_attr 'acr_webhook.name')" \
            --resource-group "$(svc_attr 'acr_webhook.resource_group')" \
            --registry "$(svc_attr 'acr_webhook.registry')" \
            --scope "$(svc_attr 'container.name'):$(svc_attr 'container.tag')" \
            --status "$(svc_attr 'acr_webhook.status')" \
            --actions $(webhook_actions) \
            --uri "$(webhook_uri)"
    fi
    true
}

function config_logging () {
    if [[ '0' != "$(svc_attr_size 'logging')" ]]; then
        # shellcheck disable=SC2046
        $AZ_TRACE webapp log config \
            --name "$(service_name)" \
            --resource-group "$(service_resource_group)" \
            --application-logging "$(svc_attr 'logging.application_logging')" \
            --detailed-error-messages "$(svc_attr 'logging.detailed_error_messages')" \
            --docker-container-logging "$(svc_attr 'logging.docker_container_logging')" \
            --failed-request-tracing "$(svc_attr 'logging.failed_request_tracing')" \
            --level "$(svc_attr 'logging.level')" \
            --web-server-logging "$(svc_attr 'logging.web_server_logging')"
    fi
    true
}

function config_tls () {
    if [[ '0' != "$(svc_attr_size 'tls')" ]]; then
        # shellcheck disable=SC2046
        $AZ_TRACE webapp update \
            --name "$(service_name)" \
            --resource-group "$(service_resource_group)" \
            --https-only "$(svc_attr 'tls')"
    fi
    true
}

function option_if_present () {
    local -r option_key="${1}"
    local -r option_config="${2}"
    if [[ '0' != "$(svc_attr_size "${option_config}")" ]]; then
        printf -- "--%s %s" "${option_key}" "$(svc_attr "${option_config}" )"
    fi
    true
}

function option_string_if_present () {
    local -r option_flag="${1}"
    local -r option_attr="${2}"
    local -r option_key="${3}"
    if [[ '0' != "$(svc_attr_size "${option_attr}.${option_key}")" ]]; then
        printf -- "--%s %s" "${option_flag}" "$(svc_string "${option_attr}" "${option_key}" )"
    fi
    true
}

function config_access_restriction () {
    local -r index="${1}"
    # azure preview feature @@ TODO techdebt
    # shellcheck disable=SC2046
    $AZ_TRACE webapp config access-restriction add \
        --name "$(service_name)" \
        --resource-group "$(service_resource_group)" \
        --priority "$(svc_attr "access_restrictions[${index}].priority")" \
        --rule-name "'$(svc_attr "access_restrictions[${index}].rule_name")'" \
        --action "$(svc_attr "access_restrictions[${index}].action")" \
        --description "'$(svc_attr "access_restrictions[${index}].description")'" \
        --ignore-missing-endpoint "$(svc_attr "access_restrictions[${index}].ignore_missing_endpoint")" \
        $(option_if_present 'ip-address' "access_restrictions[${index}].ip_address") \
        --scm-site "$(svc_attr "access_restrictions[${index}].scm_site")" \
        $(option_if_present 'subnet' "access_restrictions[${index}].subnet") \
        $(option_string_if_present 'vnet-name' "access_restrictions[${index}]" 'vnet_name')
}

function config_access_restrictions () {
    if [[ '0' != "$(svc_attr_size 'access_restrictions')" ]]; then
        local i
        for i in $(seq 0 $(( $(svc_attr_size 'access_restrictions') - 1)) ); do
            config_access_restriction "${i}"
        done
    fi
    true
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
    enable_container_continuous_deployment
    set_app_settings
    set_webhook
    config_logging
    config_tls
    config_access_restrictions
}

function create_service_if_needed () {
    service_already_exists || deploy_service
}

create_service_if_needed
