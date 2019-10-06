#!/usr/bin/env bash
# usage: create_public_ip_if_needed.sh public_ip_name

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
declare -rx PUBLIC_IP_NAME="${1}"

function public_ip_name (){
    echo "${PUBLIC_IP_NAME}"
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

function iaas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function public_ip_resource_group () {
    iaas_configuration | jq -r -e ".networking.public_ip[] | select(.name == \"$(public_ip_name)\") | .resource_group"
}

function public_ip_already_exists () {
    az network public-ip show --name  "$(public_ip_name)" --resource-group "$(public_ip_resource_group)" > /dev/null 2>&1
}

function create_public_ip () {
    echo az network public-ip create \
        --name "$(public_ip_name)" \
        --resource-group "$(public_ip_resource_group)" \
        --allocation-method 'Static'
}

function create_public_ip_if_needed () {
    public_ip_already_exists || create_public_ip
}

create_public_ip_if_needed
