#!/usr/bin/env bash
# usage: create_service_principal_if_needed.sh service_principal_name

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
declare -rx SERVICE_PRINCIPAL_NAME="${1}"

function service_principal_name (){
    echo "${SERVICE_PRINCIPAL_NAME}"
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

function service_principal_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".service_principals[] | select(.name == \"$(service_principal_name)\") | .${attr}"
}

function service_principal_string_attr () {
    local -r attr="${1}"
    local -r key="${2}"
    service_principal_attr "${attr}" | jq -r -e ".${key} | if type==\"array\" then join(\"\") else . end"
}

function sp_name () {
    service_principal_attr 'name'
}

function kv_name () {
    service_principal_attr 'key_vault.vault'
}

function kv_secret_name () {
    service_principal_attr 'key_vault.secret_name'
}

function kubernetes_cluster_already_exists () {
    $AZ_TRACE aks show \
        --name "$(kubernetes_cluster_name)" \
        --resource-group "$(kubernetes_cluster_resource_group)" \
        > /dev/stderr 2>&1
    false
}

function az_create_service_principal () {
    az ad sp create-for-rbac \
        --name "http://$(sp_name)" \
        --role "$(service_principal_attr 'role')" \
        --output 'json' \
        --scopes "$(service_principal_string_attr    '' 'scopes')" \
    | tee /dev/stderr
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    $AZ_TRACE keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function set_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    local -r secret="${3}"
    $AZ_TRACE keyvault secret set \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        --description 'secure secret from deployment automation' \
        --value "${secret}" \
        2> /dev/stderr
}

function kv_set () {
    local -r secret_name="${1}"
    local -r secret="${2}"
    set_vault_secret "$(kv_name)" "${secret_name}" "${secret}"
}

function persist_service_principal_details_to_kv () {
    local -r sp_json="${1}"
    kv_set "$(kv_secret_name)-spdata" "${sp_json}" || true
    kv_set "$(kv_secret_name)-app-id" "$(jq -r -e '.appId // "fixme" ' <<< "${sp_json}")" || true
    kv_set "$(kv_secret_name)-secret" "$(jq -r -e '.password // "fixme" ' <<< "${sp_json}")" || true
}

function create_service_principal () {
    persist_service_principal_details_to_kv "$(az_create_service_principal)"
}

function service_principal_show () {
    az ad sp show \
        --id "http://$(sp_name)" \
    2> /dev/null
}

function service_principal_already_exists () {
    # sp must exist, 3 secrets must exist and reconcile with each other and the sp data
    local sp_show sp_data sp_app_id sp_secret
    sp_show="$(service_principal_show)"
    sp_data="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-spdata")"
    sp_app_id="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-app-id")"
    sp_secret="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-secret")"
    if [[ -n "${sp_show}" ]] && [[ -n "${sp_data}" ]] && [[ -n "${sp_app_id}" ]] && [[ -n "${sp_secret}" ]]; then
        if [[ "$(jq -r -e '.appDisplayName' <<< "${sp_show}")" == "$(jq -r -e '.displayName' <<< "${sp_data}")" ]]; then
            if [[ "$(jq -r -e '.appId' <<< "${sp_show}")" == "$(jq -r -e '.appId' <<< "${sp_data}")" ]]; then
                if [[ "$(jq -r -e '.appOwnerTenantId' <<< "${sp_show}")" == "$(jq -r -e '.tenant' <<< "${sp_data}")" ]]; then
                    if [[ "${sp_secret}" == "$(jq -r -e '.password' <<< "${sp_data}")" ]]; then
                        if [[ "${sp_app_id}" == "$(jq -r -e '.appId' <<< "${sp_data}")" ]]; then
                            true
                            return
                        fi
                    fi
                fi
            fi
        fi
    fi
    false
}


function create_service_principal_if_needed () {
    printf 'testing sp [%s]\n' "$(sp_name)"
    if ! service_principal_already_exists; then
        printf 'creating sp [%s]\n' "$(sp_name)"
        create_service_principal || true
    fi
}

create_service_principal_if_needed
