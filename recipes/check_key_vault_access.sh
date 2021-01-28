#!/usr/bin/env bash
# usage: check_key_vault_access.sh "deployment_name"

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
    "/bedrock/recipes/get_deployment_json_by_name.sh" "${deployment_name}"
}

function read_raw_configuration () {
    local -r deployment_json="${1}"
    "/bedrock/recipes/read_raw_configuration.sh" "${deployment_json}"
}

function get_app () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.app' <<< "${deployment_json}"
}

function get_env () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.name' <<< "${deployment_json}"
}

function process_app_env () {
    local -r app="${1:-br}"
    local -r env="${2:-env}"
    sed -e "s|##app##|${app}|g" \
        -e "s|##env##|${env}|g" \
        -e "s|##app-env##|${app}-${env}|g" \
        -e "s|##app_env##|${app}_${env}|g" \
        -e "s|##appenv##|${app}${env}|g"
}

function get_target_cluster_config_json () {
    local -r deployment_json="${1}"
    local app env
    app="$(get_app "${deployment_json}")"
    env="$(get_env "${deployment_json}")"
    read_raw_configuration "${deployment_json}" \
      | process_app_env "${app}" "${env}" \
      | "/bedrock/recipes/join_string_arrays.sh"
}

function explore_key_vault_access () {
    local -r target_cluster_config_json="${1}"
    local -r deployment_json="${2}"
    local subscription vault_name
    local retval=0
    subscription="$(jq -r -e '.target.metadata.azure.default.subscription' <<< "${target_cluster_config_json}")"
    vault_name="$(jq -r '.target.paas.keyvaults[]? | [ select(.action == "create") ] | .[0].name // empty' <<< "${target_cluster_config_json}")"
    secret_name="$(jq -r '.k8s.tls_secret_name? // empty' <<< "${deployment_json}")"
    if [[ -n "${vault_name}" ]]; then
    if ! az keyvault list --subscription "${subscription}" -o table; then
        printf 'NO ACCESS TO LIST OF KEY VAULTS\n'
        retval=1
      elif ! az keyvault secret list --subscription "${subscription}" --vault-name "${vault_name}" -o table; then
        printf 'NO ACCESS TO LIST OF SECRETS\n'
        retval=1
      elif [[ -n "${secret_name}" ]]; then
    if ! az keyvault secret show --subscription "${subscription}" --vault-name "${vault_name}" --name "${secret_name}" > /dev/null; then
        printf 'NO ACCESS TO SPECIFIC SECRET\n'
        retval=1
    fi
      fi
    fi
    (( retval == 0 ))
}

function check_key_vault_access () {
    local -r deployment_name="${1}"
    local deployment_json target_cluster_config_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    target_cluster_config_json="$(get_target_cluster_config_json "${deployment_json}")"
    explore_key_vault_access "${target_cluster_config_json}" "${deployment_json}"
}

check_key_vault_access "${@}"
