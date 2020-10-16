#!/usr/bin/env bash
# usage: deploy_datadog.sh

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

function deploy_datadog () {
    local -r deployment_name="${1}"
    local deployment_json datadog_enabled
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    datadog_enabled="$(jq -r -e '.paas.datadog.enabled' <<< "${deployment_json}")"
    if [[ "${datadog_enabled}" == 'true' ]]; then
        local datadog_namespace k8s_context
        datadog_namespace="$(jq -r -e '.paas.datadog.namespace' <<< "${deployment_json}")"
        k8s_context="$(jq -r -e '.k8s.context' <<< "${deployment_json}")"
        kubectl --context "${k8s_context}" create ns "${datadog_namespace}" 2> /dev/null || true
        jq -r -e '.paas.datadog.values' <<< "${deployment_json}"
        helm upgrade --install \
            --kube-context "${k8s_context}" \
            --namespace "${datadog_namespace}" \
            --history-max 20 \
            'datadog' \
            "$(repo_root)/configuration/k8s/charts/datadog/" \
            --timeout "10m" \
            --wait \
            --values <(jq -r -e '.paas.datadog.values' <<< "${deployment_json}")
    fi
}

deploy_datadog "${@}"
