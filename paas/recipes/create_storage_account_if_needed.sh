#!/usr/bin/env bash
# usage: create_storage_account_if_needed.sh storage_account

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
declare -rx kubernetes_cluster_NAME="${1}"

function kubernetes_cluster_name (){
    echo "${kubernetes_cluster_NAME}"
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

function storage_account_json () {
    local -r sa_name="${1}"
    jq -r -e --arg sa_name "${sa_name}" '.storage.accounts[]? | select(.name | test($sa_name))'
}

function storage_account_available () {
    local sa_name_json="${1}"
    az storage account check-name \
        --name "$(jq -r -e '.name' <<< "${sa_name_json}" )" \
    | jq -r -e '.nameAvailable'
}

function update_storage_account () {
    local sa_name_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE storage account update \
        --name "$(jq -r -e '.name' <<< "${sa_name_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${sa_name_json}" )" \
        --encryption-services "$(jq -r -e '.encryption_services' <<< "${sa_name_json}" )" \
        --https-only "$(jq -r -e '.https_only' <<< "${sa_name_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${sa_name_json}" )" \
        --tags $(jq -r -e '.tags' <<< "${sa_name_json}" )
}

function create_storage_account () {
    local sa_name_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE storage account create \
        --name "$(jq -r -e '.name' <<< "${sa_name_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${sa_name_json}" )" \
        --location "$(jq -r -e '.location' <<< "${sa_name_json}" )" \
        --encryption-services "$(jq -r -e '.encryption_services' <<< "${sa_name_json}" )" \
        --https-only "$(jq -r -e '.https_only' <<< "${sa_name_json}" )" \
        --kind "$(jq -r -e '.kind' <<< "${sa_name_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${sa_name_json}" )" \
        --tags $(jq -r -e '.tags' <<< "${sa_name_json}" )
}

function create_or_update_storage_account () {
    local sa_name_json="${1}"
    if [[ "$(storage_account_available "${sa_name_json}" )" == 'true' ]]; then
        create_storage_account "${sa_name_json}"
    else
        update_storage_account "${sa_name_json}"
    fi
}

function create_storage_account_if_needed () {
    local -r sa_name="${1}"
    local sa_name_json
    sa_name_json="$(paas_configuration | storage_account_json "${sa_name}")"
    printf 'Creating or Updating Storage Account [%s]\n' "${sa_name}" > /dev/stderr
    create_or_update_storage_account "${sa_name_json}"
}

create_storage_account_if_needed "$@"
