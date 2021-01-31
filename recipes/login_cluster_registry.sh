#!/usr/bin/env bash
# usage: login_cluster_registry.sh

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

function acr_login () {
    local -r desired_repo="${1}"
    az acr login -n "${desired_repo}"
}

function get_helm_registry_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.registry.name' <<< "${deployment_json}"
}

function get_helm_registry_url () {
    local -r deployment_json="${1}"
    jq -r '.helm.umbrella.registry.url // ""' <<< "${deployment_json}"
}

function login_cluster_registry () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    acr_login "$(get_helm_registry_name "${deployment_json}")"
}

login_cluster_registry "$@"
