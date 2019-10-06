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

function iaas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function iaas_location () {
    iaas_configuration | jq -r -e '.location'
}

function resource_group_names () {
    iaas_configuration | jq -r -e '[.resource_groups[] | select(.action == "create") | .name ] | @tsv'
}

function deploy_resource_groups () {
    for rg in $(resource_group_names); do
        invoke_layer 'iaas' 'create_resource_group_if_needed' "${rg}" "$(iaas_location)"
    done
}

function public_ip_names () {
    iaas_configuration | jq -r -e '[.networking.public_ip[] | select(.action == "create") | .name ] | @tsv'
}

function deploy_public_ips () {
    for ip_name in $(public_ip_names); do
        invoke_layer 'iaas' 'create_public_ip_if_needed' "${ip_name}"
    done
}

function dns_hosts () {
    iaas_configuration | jq -r -e '[.networking.dns_a_records[] | select(.action == "create") | .host ] | @tsv'
}

function deploy_dns_a_records () {
    for dns_host in $(dns_hosts); do
        invoke_layer 'iaas' 'create_dns_a_record_if_needed' "${dns_host}"
    done
}

function vnet_names () {
    iaas_configuration | jq -r -e '[.networking.vnets[] | select(.action == "create") | .name ] | @tsv'
}

function deploy_vnets () {
    for vnet_name in $(vnet_names); do
        invoke_layer 'iaas' 'create_vnet_if_needed' "${vnet_name}"
    done
}

function deploy_networking () {
    deploy_public_ips
    deploy_dns_a_records
    deploy_vnets
}

function deploy_iaas () {
    deploy_resource_groups
    deploy_networking
}

deploy_iaas
