#!/usr/bin/env bash
# usage: create_database_server_if_needed.sh database_server_name

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
declare -rx DATABASE_SERVER_NAME="${1}"

function database_server_name () {
    echo "${DATABASE_SERVER_NAME}"
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
    echo -n "$(repo_root)/${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function server_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".databases.servers[] | select(.name == \"$(database_server_name)\") | .${attr}"
}

function database_server_resource_group () {
    server_attr 'resource_group'
}

function database_server_admin_name () {
    server_attr 'admin_name'
}

function fetch_kv_database_server_admin_password () {
    az keyvault secret show \
        --vault-name "$(server_attr 'admin_password_kv.vault')" \
        --name "$(server_attr 'admin_password_kv.secret_name')" \
        2> /dev/null \
    | jq -r '.value'
}

function random_key () {
    hexdump -n 27 -e '"%02X"'  /dev/urandom
}

function create_kv_database_server_admin_password () {
    local password
    password=$(random_key)
    az keyvault secret set \
        --vault-name "$(server_attr 'admin_password_kv.vault')" \
        --name "$(server_attr 'admin_password_kv.secret_name')" \
        --description "admin password for database server [$(database_server_name)]" \
        --value "${password}" \
    | jq -r '.value'
}

function database_server_admin_password () {
    local password
    password=$(fetch_kv_database_server_admin_password)
    if [[ -z "${password:-}" ]]; then
        password=$(create_kv_database_server_admin_password)
        if [[ -z "${password:-}" ]]; then
            return 1
        fi
    fi
    echo -n "${password}"
}

function database_server_already_exists () {
    az sql server \
        --name "$(database_server_name)" \
        --resource-group "$(database_server_resource_group)" \
        > /dev/null 2>&1
}

function deploy_database_server () {
    $AZ_TRACE sql server create \
        --name "$(database_server_name)" \
        --resource-group "$(database_server_resource_group)" \
        --assign-identity \
        --admin-user "$(database_server_admin_name)" \
        --admin-password "$(database_server_admin_password)"
}

function create_database_server_if_needed () {
    database_server_already_exists || deploy_database_server
}

create_database_server_if_needed
