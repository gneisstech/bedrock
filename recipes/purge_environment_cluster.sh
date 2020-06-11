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

function purge_environment_cluster () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    TARGET_CONFIG="$(get_target_config "${deployment_json}")" AZ_TRACE=az "$(repo_root)/recipes/purge_environment.sh"
}

purge_environment_cluster "${@}"
