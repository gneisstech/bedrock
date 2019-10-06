#!/usr/bin/env bash
# usage: create_keyvault_if_needed.sh ResourceGroupName KeyVaultName

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
declare -rx KEYVAULT_NAME="${1}"
declare -rx RESOURCE_GROUP_NAME="fake_name"

function repo_root () {
    git rev-parse --show-toplevel
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function keyvault_name () {
    echo "${KEYVAULT_NAME}"
}

function get_keyvault_rg () {
    paas_configuration | jq -r -e ".keyvaults[] | select ( .name == \"$(keyvault_name)\" ) | .resource_group"
}

function keyvault_already_exists () {
    az keyvault show --name "$(keyvault_name)" --resource-group "$(get_keyvault_rg)" > /dev/null 2>&1
}

function create_keyvault () {
  echo az keyvault create \
    --name "$(keyvault_name)" \
    --resource-group "$(get_keyvault_rg)" \
    --enabled-for-template-deployment
}

function create_keyvault_if_needed () {
    keyvault_already_exists || create_keyvault
}

create_keyvault_if_needed
