#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_service_principal_if_needed.sh service_principal_name

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

function service_principal_name () {
    echo "${SERVICE_PRINCIPAL_NAME}"
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

function paas_configuration () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function target_env () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.env'
}

function target_app () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.app'
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

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function get_prebuilt_sp_info () {
    local vault secret_name
    vault="$(printf '%s-devops-kv' "$(target_app)")"
    secret_name="$(printf '%s-%s-devops-sp-info' "$(target_app)" "$(target_env)")"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/stderr \
    | jq -r '.value'
}

function az_create_service_principal () {
    if ! is_azure_pipeline_build; then
        if [[ "${AZ_TRACE}" == "az" ]]; then
            # shellcheck disable=SC2046
            $AZ_TRACE ad sp create-for-rbac \
                --name "http://$(sp_name)" \
                --role "$(service_principal_attr 'role')" \
                --output 'json' \
                --scopes $(service_principal_string_attr    '' 'scopes')
        fi
    else
        printf '>>> using prebuilt sp info <<<' > /dev/stderr
        get_prebuilt_sp_info
    fi
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r -e '.value'
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
    if [[ -n "${sp_json}" ]]; then
        kv_set "$(kv_secret_name)-spdata" "${sp_json}" > /dev/stderr || true
        kv_set "$(kv_secret_name)-app-id" "$(jq -r -e '.appId // "fixme" ' <<< "${sp_json}")" > /dev/stderr || true
        kv_set "$(kv_secret_name)-secret" "$(jq -r -e '.password // "fixme" ' <<< "${sp_json}")" > /dev/stderr || true
        printf 'sp_json [%s] set in vault [%s]\n' "${sp_json}" "$(kv_name)" > /dev/stderr
        # get_vault_secret "$(kv_name)" "$(kv_secret_name)-spdata"
        # get_vault_secret "$(kv_name)" "$(kv_secret_name)-app-id"
        # get_vault_secret "$(kv_name)" "$(kv_secret_name)-secret"
    fi
}

function create_service_principal () {
    persist_service_principal_details_to_kv "$(az_create_service_principal)" 2> /dev/null
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
    sp_data="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-spdata")" || true
    sp_app_id="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-app-id")" || true
    sp_secret="$(get_vault_secret "$(kv_name)" "$(kv_secret_name)-secret")" || true
    if [[ -z "${sp_app_id}" ]] || [[ -z "${sp_secret}" ]]; then
        printf -- '->sp required information missing from vault\n'
        false
        return
    else
        # use sp as provisioned in vault
        printf -- '->sp information in vault presumed accurate sp_app_id [%s]\n' "${sp_app_id}"
    fi
    # audit sp information as a warning to administrator
    if [[ -n "${sp_show}" ]]; then
        local showDisplayName vaultDisplayName
        showDisplayName="$(jq -r -e '.appDisplayName' <<< "${sp_show}")"
        vaultDisplayName="$(jq -r -e '.displayName' <<< "${sp_data}")"
        if [[ "${showDisplayName}" != "${vaultDisplayName}" ]]; then
            printf -- '--->AAD sp displayName [%s] does not match appDisplay name [%s] in vault\n' "${showDisplayName}" "${vaultDisplayName}"
        fi
        local showAppId vaultAppId
        showAppId="$(jq -r -e '.appId' <<< "${sp_show}")"
        vaultAppId="$(jq -r -e '.appId' <<< "${sp_data}")"
        if [[ "${showAppId}" != "${vaultAppId}" ]]; then
            printf -- '--->AAD sp appId [%s] does not match appId  [%s] in vault\n' "${showAppId}" "${vaultAppId}"
        fi
        local showAppOwnerTenantId vaultTenant
        showAppOwnerTenantId="$(jq -r -e '.appOwnerTenantId' <<< "${sp_show}")"
        vaultTenant="$(jq -r -e '.tenant' <<< "${sp_data}")"
        if [[ "${showAppOwnerTenantId}" != "${vaultTenant}" ]]; then
            printf -- '--->AAD sp tenant [%s] does not match tenant  [%s] in vault\n' "${showAppOwnerTenantId}" "${vaultTenant}"
        fi
    fi
    if [[ -n "${sp_data}" ]]; then
        if [[ "${sp_secret}" != "$(jq -r -e '.password' <<< "${sp_data}")" ]]; then
            printf -- '--->vault sp_data password does not match vault password for SP\n'
        fi
        if [[ "${sp_app_id}" != "$(jq -r -e '.appId' <<< "${sp_data}")" ]]; then
            printf -- '--->vault sp_data appId [%s] does not match vault appId [%s] for SP\n' "$(jq -r -e '.appId' <<< "${sp_data}")" "${sp_app_id}"
        fi
    fi
    true
}

function create_service_principal_if_needed () {
    printf 'testing sp [%s]\n' "$(sp_name)" > /dev/stderr
    if ! service_principal_already_exists; then
        printf '  creating sp [%s]\n' "$(sp_name)" > /dev/stderr
        create_service_principal || true
        # service_principal_show || true
    fi
}

create_service_principal_if_needed
