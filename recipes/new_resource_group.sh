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

function new_resource_group () {
  az group create --name "$(rg_name)" --location "$(rg_location)"
}

new_resource_group
