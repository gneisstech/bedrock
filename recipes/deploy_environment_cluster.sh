#!/usr/bin/env bash
# usage: deploy_environment_cluster.sh

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

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function get_target_config () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.config' <<< "${deployment_json}"
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(repo_root)/configuration/deployments/cf_deployments.yaml" |
        jq -r -e \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

function read_configuration () {
    local -r config_filename="${1}"
    yq read --tojson "${config_filename}"
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
    local -r app="${1:-cf}"
    local -r env="${2:-env}"
    sed -e "s|##app##|${app}|g" \
        -e "s|##env##|${env}|g" \
        -e "s|##app-env##|${app}-${env}|g" \
        -e "s|##app_env##|${app}_${env}|g" \
        -e "s|##appenv##|${app}${env}|g"
}

function populate_config_file () {
    local -r deployment_json="${1}"
    local -r new_config_file="${2}"
    local original_config_file
    original_config_file="$(get_target_config "${deployment_json}")"
    read_configuration "${original_config_file}" \
    | process_app_env "$(get_app "${deployment_json}")" "$(get_env "${deployment_json}")" \
    > "${new_config_file}"
}

function deploy_environment_cluster () {
    local -r deployment_name="${1}"
    local -r new_config="./.new_config"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    populate_config_file "${deployment_json}" "$(repo_root)/${new_config}"
    TARGET_CONFIG="${new_config}" AZ_TRACE=az "$(repo_root)/recipes/deploy_environment.sh"
    rm -f "${new_config}"
}

deploy_environment_cluster "${@}"
