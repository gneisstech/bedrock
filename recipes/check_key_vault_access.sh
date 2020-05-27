#!/usr/bin/env bash
# usage: deploy_umbrella_chart_to_dev.sh

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

function repo_root () {
    git rev-parse --show-toplevel
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(repo_root)/configuration/deployments/cf_deployments.yaml" |
        jq -r -e \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

function get_target_config_file_name () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.config' <<< "${deployment_json}"
}

function read_configuration () {
    local -r config_filename="${1}"
    yq read --tojson "${config_filename}"
}

function get_target_cluster_config_json () {
    local -r config_filename="${1}"
    read_configuration "${config_filename}" \
        | "$(repo_root)/recipes/join_string_arrays.sh"
}

function explore_key_vault_access () {
    local -r target_cluster_config_json="${1}"
    local subscription vault_name
    subscription="$(jq -r -e '.target.metadata.default_azure_subscription' <<< "${target_cluster_config_json}")"
    vault_name="$(jq -r -e '.target.paas.keyvaults[1].name' <<< "${target_cluster_config_json}")"
    secret_name='wildcarddevatrius-iotcom'
    set -o xtrace
        az keyvault list --subscription "${subscription}"
        az keyvault secret list --subscription "${subscription}" --vault-name "${vault_name}"
        az keyvault secret show --subscription "${subscription}" --vault-name "${vault_name}" --name "${secret_name}" > /dev/null
    set +o xtrace
}

function check_key_vault_access () {
    local -r deployment_name="${1}"
    local deployment_json target_config_filename target_cluster_config_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    target_config_filename="$(get_target_config_file_name "${deployment_json}")"
    target_cluster_config_json="$(get_target_cluster_config_json "${target_config_filename}")"
    explore_key_vault_access "${target_cluster_config_json}"
}

set -x
check_key_vault_access "${@}"
