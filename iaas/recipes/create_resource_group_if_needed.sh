#!/usr/bin/env bash
# usage: docker_install.sh

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
declare -rx RESOURCE_GROUP_NAME="${1}"
declare -rx RESOURCE_GROUP_LOCATION="${2}"

function rg_name (){
    echo "${RESOURCE_GROUP_NAME}"
}

function rg_location () {
    echo "${RESOURCE_GROUP_LOCATION}"
}

function resource_group_already_exists () {
    az group show --name  "$(rg_name)" > /dev/null 2>&1
}

function create_resource_group () {
    echo az group create --name "$(rg_name)" --location "$(rg_location)"
}

function create_resource_group_if_needed () {
    resource_group_already_exists || create_resource_group
}

create_resource_group_if_needed
