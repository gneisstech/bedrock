#!/usr/bin/env bash
# usage: purge_environment_cluster.sh

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

function populate_config_file () {
    local -r deployment_json="${1}"
    local -r new_config_file="${2}"
    local app env
    app="$(get_app "${deployment_json}")"
    env="$(get_env "${deployment_json}")"
    read_raw_configuration "${deployment_json}" \
      | process_app_env "${app}" "${env}" \
      > "${new_config_file}"
}

function purge_environment_cluster () {
    local -r deployment_name="${1}"
    local -r new_config="/tmp/.new_config"
    local app env deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    app="$(get_app "${deployment_json}")"
    env="$(get_env "${deployment_json}")"
    populate_config_file "${deployment_json}" "${new_config}"
    TARGET_CONFIG="${new_config}" AZ_TRACE=az "/bedrock/recipes/purge_environment.sh"
    rm -f "${new_config}"
}

purge_environment_cluster "${@}"
