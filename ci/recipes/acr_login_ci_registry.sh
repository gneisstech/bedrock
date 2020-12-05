#!/usr/bin/env bash
# usage: acr_login_ci_registry.sh

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
    yq r --tojson "$(repo_root)/configuration/deployments/br_deployments.yaml" |
        jq -r -e \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
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

function acr_login_cluster_registry () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    acr_login "$(get_helm_registry_name "${deployment_json}")"
}

function acr_login_ci_registry () {
    pushd "${BUILD_REPOSITORY_LOCALPATH:-.}"
    pwd
        SECONDS=0
        acr_login_cluster_registry "BR_CI"
        DD_CLIENT_API_KEY="${1:-}" DD_CLIENT_APP_KEY="${2:-}" "$(repo_root)/ci/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
    popd
}

acr_login_ci_registry "$@" 2> >(while read -r line; do (echo "STDERR: $line"); done)
