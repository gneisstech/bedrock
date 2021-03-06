#!/usr/bin/env bash
# usage: publish_packaged_chart_to_env.sh
# assumes that Chart.yaml and chart-blah.tgz are in the repo_root dir, but not added to git

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

function get_helm_chart_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.name' <<< "${deployment_json}"
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    "/bedrock/recipes/get_deployment_json_by_name.sh" "${deployment_name}"
}

function get_helm_registry_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.registry.name' <<< "${deployment_json}"
}

function get_helm_registry_url () {
    local -r deployment_json="${1}"
    jq -r '.helm.umbrella.registry.url // ""' <<< "${deployment_json}"
}

function extract_chart_version () {
    local theChartfile="${1}"
    grep -i '^version:' "${theChartfile}" | sed -e 's|.*: ||'
}

function publish_new_umbrella () {
    local -r target_registry="${1}"
    local -r chart_name="${2}"
    local chart_package
    chart_package="${chart_name}-$(extract_chart_version "./Chart.yaml").tgz"

    ls -l
    printf 'chart package name [%s]\n' "${chart_package}"
    helm repo remove "${target_registry}" 2> /dev/null || true
    az acr helm repo add --name "${target_registry}" 2> /dev/null
    if az acr helm push -n "${target_registry}" "${chart_package}" 2> /dev/null; then
        result=0
    else
        printf 'Race condition resolved in favor of earlier job\n'
        result=0
    fi
    (( result == 0 ))
}

function publish_packaged_chart_to_env () {
    local -r target_deployment_name="${1}"
    local target_deployment_json target_registry chart_file_name
    target_deployment_json="$(get_deployment_json_by_name "${target_deployment_name}")"
    target_registry="$(get_helm_registry_name "${target_deployment_json}")"
    chart_file_name="$(get_helm_chart_name "${target_deployment_json}")"

    publish_new_umbrella "${target_registry}" "$(repo_root)/${chart_file_name}" || true
    rm -f "$(repo_root)/${chart_file_name}" "$(repo_root)/Chart.yaml"
}

publish_packaged_chart_to_env "${@}"
