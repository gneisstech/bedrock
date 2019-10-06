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

# Arguments
# ---------------------
declare -rx DATABASE_SERVER_NAME="${1}"

function database_server_name () {
    echo "${DATABASE_SERVER_NAME}"
}

function database_server_admin_password () {
    echo "changeme-soon-@@-TODO"
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

function database_server_resource_group () {
    paas_configuration | jq -r -e ".databases.servers[] | select(.name == \"$(database_server_name)\") | .resource_group"
}

function database_server_already_exists () {
    az sql server \
        --name "$(database_server_name)" \
        --resource-group "$(database_server_resource_group)" \
        > /dev/null 2>&1
}

function database_server_admin_name () {
    paas_configuration | jq -r -e ".databases.servers[] | select(.name == \"$(database_server_name)\") | .admin_name"
}

function deploy_database_server () {
    echo az sql server create \
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
