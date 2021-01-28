#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml register_application_if_needed.sh service_name

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
declare -rx SERVICE_GROUP="${1}"

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
    saas_configuration | jq -r -e ".${SERVICE_GROUP} | .${attr} // empty"
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

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    if [[ -n "${vault}${secret_name}" ]]; then
        az keyvault secret show \
            --vault-name "${vault}" \
            --name "${secret_name}" \
        | jq -r '.value'
    fi
}

function get_current_subscription () {
    az account show | jq -r '.id'
}

function existing_reply_urls () {
    az ad app show --id "$(svc_attr 'application_id')" | jq -r -e '.replyUrls'
}

function add_to_jq_array () {
    local -r newElements="${1}"
    jq -r -e ". += [ \"${newElements}\" ] | unique"
}

function new_reply_urls () {
    existing_reply_urls | add_to_jq_array "$(svc_string 'variables' 'app_auth_callback_url')"
}

function new_reply_urls_array () {
    new_reply_urls | jq -r -e '@tsv'
}

function add_reply_url_to_application_if_needed () {
    # shellcheck disable=SC2046
    $AZ_TRACE ad app update \
        --id "$(svc_attr 'application_id')" \
        --reply-urls $(new_reply_urls_array)
}

function add_client_secret_to_application () {
    local -r secret="${1}"
    if [[ -n "${secret}" ]]; then
        $AZ_TRACE ad app credential reset --append  \
            --id "$(svc_attr 'application_id')" \
            --credential-description "$(svc_attr 'client_secret.description')" \
            --password "${secret}"
    fi
}

function update_target_application () {
    local -r previous_subscription="${1}"
    local secret
    secret="$(get_vault_secret "$(svc_attr 'client_secret.vault')" "$(svc_attr 'client_secret.secret_name')" )"
    if [[ -n "${secret}" ]]; then
        local tenant
        tenant="$(svc_attr 'tenant')"
        if [[ -n "${tenant}" ]]; then
            az account set --subscription "$(svc_attr 'tenant')"
            add_reply_url_to_application_if_needed
            add_client_secret_to_application "${secret}"
        fi
    fi
    az account set --subscription "${previous_subscription}"
}

function register_application_if_needed () {
    update_target_application "${previous_subscription}"
}

#
# word to the wise, run `az login --allow-no-subscriptions` or equivalent before running this script
#


previous_subscription="$(get_current_subscription)"
function restore_subscription () {
    az account set --subscription "${previous_subscription}"
}
trap restore_subscription 0

( register_application_if_needed )


