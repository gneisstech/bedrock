#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml apply_service_access_restrictions.sh service_name

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
    "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    printf '%s' "${TARGET_CONFIG}"
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
    hexdump -n 16 -e '16/1 "%02.2X"' /dev/urandom
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
    local i=0
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
        (( ++i ))
    done

    i=0
    while (( ${#myarray[@]} > i )); do
        printf '%s' "${myarray[i++]}"
    done
}

function interpolate_functions () {
    awk '{gsub(/##/,"\n"); print}' | dispatch_functions
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
        $(option_string_if_present 'subnet' "access_restrictions[${index}]" 'subnet')
}

function config_access_restrictions () {
    if [[ '0' != "$(svc_attr_size 'access_restrictions')" ]]; then
        local i
        for i in $(seq 0 $(( $(svc_attr_size 'access_restrictions') - 1 )) ); do
            config_access_restriction "${i}"
        done
    fi
    true
}

function apply_service_access_restrictions () {
    config_access_restrictions
}

apply_service_access_restrictions
