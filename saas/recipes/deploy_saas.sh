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

function saas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function service_names () {
    local -r service_group="${1}"
    saas_configuration | jq -r -e "[.${service_group}.services[] | select(.action == \"create\") | .name ] | @tsv"
}

function deploy_services () {
    local -r service_group="${1}"
    local service_name
    for service_name in $(service_names "${service_group}"); do
        invoke_layer 'saas' 'create_service_if_needed' "${service_name}" "${service_group}"
    done
}

function application_gateway_names () {
    saas_configuration | jq -r -e '[.application_gateways[] | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_application_gateways () {
    local gateway_name
    for gateway_name in $(application_gateway_names); do
        invoke_layer 'saas' 'create_application_gateway_if_needed' "${gateway_name}"
    done
}

function register_application () {
    local -r service_group="${1}"
    invoke_layer 'saas' 'register_application_if_needed' "${service_group}"
}

function deploy_saas () {
    deploy_services 'authn_services'
    deploy_services 'web_services'
    deploy_application_gateways
    register_application 'application_registration'
}

deploy_saas
