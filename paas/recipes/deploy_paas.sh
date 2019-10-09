#!/usr/bin/env bash
# usage: deploy_environment.sh target_environment_config.yaml

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

function keyvault_names () {
    paas_configuration | jq -r -e '[.keyvaults[] | select(.action == "create") | .name ] | @tsv'
}

function seed_secrets () {
    invoke_layer 'paas' create_registration_auth_binding_secret_if_needed
    invoke_layer 'paas' create_database_secret_if_needed
    invoke_layer 'paas' copy_tls_certificate_if_needed
}

function deploy_keyvaults () {
    local keyvault_name
    for keyvault_name in $(keyvault_names); do
        invoke_layer 'paas' 'create_keyvault_if_needed' "${keyvault_name}"
    done
#    seed_secrets
}

function database_server_names () {
    paas_configuration | jq -r -e '[.databases.servers[] | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_database_servers () {
    local server_name
    for server_name in $(database_server_names); do
        invoke_layer 'paas' 'create_database_server_if_needed' "${server_name}"
    done
}

function database_instance_names () {
    paas_configuration | jq -r -e '[.databases.instances[] | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_database_instances () {
    local instance_name
    for instance_name in $(database_instance_names); do
        invoke_layer 'paas' 'create_database_instance_if_needed' "${instance_name}"
    done
}

function deploy_databases () {
    deploy_database_servers
    deploy_database_instances
}

function server_farm_names () {
    paas_configuration | jq -r -e '[.server_farms[] | select(.action == "create") | .name ] | @tsv'
}

function deploy_server_farms () {
    local farm_name
    for farm_name in $(server_farm_names); do
        invoke_layer 'paas' 'create_server_farm_if_needed' "${farm_name}"
    done
}

function container_registry_names () {
    paas_configuration | jq -r -e '[.container_registries[] | select(.action == "create") | .name ] | @tsv'
}

function deploy_container_registries () {
    local registry_name
    for registry_name in $(container_registry_names); do
        invoke_layer 'paas' 'create_container_registry_if_needed' "${registry_name}"
    done
}

function deploy_paas () {
    deploy_keyvaults
    deploy_databases
    deploy_server_farms
    deploy_container_registries
}

deploy_paas
