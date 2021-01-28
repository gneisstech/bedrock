#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_azure_blob_store_if_needed.sh azure_blob_store

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
    "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    printf '%s/%s' "$(repo_root)" "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function azure_blob_store_json () {
    local -r bs_name="${1}"
    jq -r -e --arg bs_name "${bs_name}" '.storage.blob_store[]? | select(.name | test($bs_name))'
}

function az_cli_get_connection_string () {
    local -r sa_name="${1}"
     az storage account show-connection-string --name "${sa_name}"
}
function azure_storage_account_connection_string () {
    local bs_name_json="${1}"
    local sa_name
    sa_name="$(jq -r -e '.storage_account_name' <<< "${bs_name_json}" )"
    az_cli_get_connection_string "${sa_name}" | jq -r -e '.connectionString'
}

function azure_blob_store_exists () {
    local bs_name_json="${1}"
    az storage container exists \
        --name "$(jq -r -e '.name' <<< "${bs_name_json}" )" \
        --connection-string "$(azure_storage_account_connection_string "${bs_name_json}" )" \
    | jq -r -e '.exists'
}

function create_azure_blob_store () {
    local bs_name_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE storage container create \
        --name "$(jq -r -e '.name' <<< "${bs_name_json}" )" \
        --connection-string "$(azure_storage_account_connection_string "${bs_name_json}" )" \
        --account-name "$(jq -r -e '.storage_account_name' <<< "${bs_name_json}" )"
}

function create_or_update_azure_blob_store () {
    local bs_name_json="${1}"
    if [[ "$(azure_blob_store_exists "${bs_name_json}" )" == 'false' ]]; then
        create_azure_blob_store "${bs_name_json}"
    else
        printf 'Can not update Blob Store Container [%s]\n' "$(jq -r -e '.name' <<< "${bs_name_json}" )"
    fi
}

function create_azure_blob_store_if_needed () {
    local -r bs_name="${1}"
    local bs_name_json
    bs_name_json="$(paas_configuration | azure_blob_store_json "${bs_name}")"
    printf 'Creating or Updating Az Blob Store [%s]\n' "${bs_name}" > /dev/stderr
    create_or_update_azure_blob_store "${bs_name_json}"
}

create_azure_blob_store_if_needed "$@"
