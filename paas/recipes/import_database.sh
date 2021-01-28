#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml import_database.sh database_instance_name

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
declare -x AZ_TRACE

# Arguments
# ---------------------
declare -rx DATABASE_INSTANCE_NAME="${1}"
declare -rx BACPAC_STORAGE_ACCOUNT="${2}"
declare -rx BACPAC_CONTAINER_NAME="${3}"
declare -rx BACPAC_NAME="${4}"

function database_instance_name (){
    echo "${DATABASE_INSTANCE_NAME}"
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

function db_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".databases.instances[] | select(.name == \"$(database_instance_name)\") | .${attr}"
}

function database_instance_resource_group () {
    db_attr "resource_group"
}

function database_instance_server () {
    db_attr "server"
}

function server_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".databases.servers[] | select(.name == \"$(database_instance_server)\") | .${attr}"
}

function database_server_subscription () {
    server_attr "subscription"
}

function database_server_resource_group () {
    server_attr 'resource_group'
}

function database_server_admin_name () {
    server_attr 'admin_name'
}

function storage_account_name () {
    printf '%s' "${BACPAC_STORAGE_ACCOUNT}"
}

function container_name () {
    printf '%s' "${BACPAC_CONTAINER_NAME}"
}

function bacpac_name () {
    printf '%s' "${BACPAC_NAME}"
}

function fetch_kv_database_server_admin_password () {
    az keyvault secret show \
        --vault-name "$(server_attr 'admin_password_kv.vault')" \
        --name "$(server_attr 'admin_password_kv.secret_name')" \
        2> /dev/null \
    | jq -r '.value'
}

function database_server_admin_password () {
    printf "'%s'" "$(fetch_kv_database_server_admin_password)"
}

function expiry_date () {
    # date function options are highly sensitive to OS and shell versions
    # for mac, 'brew install coreutils' to get gnu date
    gdate --utc --date "+2 hours" '+%Y-%m-%dT%H:%MZ'
}

function az_storage_key () {
    az storage blob generate-sas \
        --account-name "$(storage_account_name)" \
        --container-name "$(container_name)" \
        --name "$(bacpac_name)" \
        --permissions 'r' \
        --expiry "$(expiry_date)" \
        -o tsv
}

function storage_key () {
    printf '"?%s"' "$(az_storage_key)"
}

function storage_uri () {
    printf "https://%s.blob.core.windows.net/%s/%s" "$(storage_account_name)" "$(container_name)" "$(bacpac_name)"
}

function database_import () {
    # shellcheck disable=SC2046,SC2086
    eval $AZ_TRACE sql db import \
        --subscription "$(database_server_subscription)" \
        --name "$(database_instance_name)" \
        --resource-group "$(database_instance_resource_group)" \
        --server "$(database_instance_server)" \
        --admin-password "$(database_server_admin_password)" \
        --admin-user "$(database_server_admin_name)" \
        --storage-key "$(storage_key)" \
        --storage-key-type 'SharedAccessKey' \
        --storage-uri "$(storage_uri)"
}

function init_trace () {
    if [[ -z "${AZ_TRACE}" ]]; then
        export AZ_TRACE="echo az"
    fi
}

function import_database () {
    date
    init_trace
    database_import
    date
}

import_database
