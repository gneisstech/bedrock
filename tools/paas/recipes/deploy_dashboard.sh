#!/usr/bin/env bash
# usage: deploy_dashboard.sh

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

function dashboard_chart_values () {
cat <<EOF
{
    "metricsScraper" : {
        "enabled" : "true"
    }
}
EOF
}

function deploy_dashboard () {
    local -r deployment_name="${1}"
    local deployment_json dashboard_enabled
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    dashboard_enabled="$(jq -r -e '.paas.dashboard.enabled' <<< "${deployment_json}")"
    if [[ "${dashboard_enabled}" == 'true' ]]; then
        local dashboard_namespace k8s_context
        dashboard_namespace="$(jq -r -e '.paas.dashboard.namespace' <<< "${deployment_json}")"
        k8s_context="$(jq -r -e '.k8s.context' <<< "${deployment_json}")"
        kubectl --context "${k8s_context}" create ns "${dashboard_namespace}" 2> /dev/null || true
        helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
        helm upgrade --install \
            --kube-context "${k8s_context}" \
            --namespace "${dashboard_namespace}" \
            --history-max 20 \
            'dashboard' \
            'kubernetes-dashboard/kubernetes-dashboard' \
            --timeout "1m" \
            --wait \
            --values <(dashboard_chart_values)
    fi
}

deploy_dashboard "${@}"
