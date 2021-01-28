#!/usr/bin/env bash
# usage: deploy_neuvector.sh

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

function neuvector_chart_values () {
cat <<EOF
{
    "cve" : {
        "updater" : {
            "enabled" : "true"
        }
    }
}
EOF
}

function deploy_neuvector () {
    local -r deployment_name="${1}"
    local deployment_json neuvector_enabled
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    neuvector_enabled="$(jq -r -e '.paas.neuvector.enabled' <<< "${deployment_json}")"
    if [[ "${neuvector_enabled}" == 'true' ]]; then
        local neuvector_namespace k8s_context
        neuvector_namespace="$(jq -r -e '.paas.neuvector.namespace' <<< "${deployment_json}")"
        k8s_context="$(jq -r -e '.k8s.context' <<< "${deployment_json}")"
        kubectl --context "${k8s_context}" create ns "${neuvector_namespace}" 2> /dev/null || true
        jq -r -e '.paas.neuvector.values' <<< "${deployment_json}"
        helm upgrade --install \
            --kube-context "${k8s_context}" \
            --namespace "${neuvector_namespace}" \
            --history-max 20 \
            'neuvector' \
            "$(repo_root)/configuration/k8s/charts/neuvector-helm/" \
            --timeout "10m" \
            --wait \
            --values <(jq -r -e '.paas.neuvector.values' <<< "${deployment_json}")
    fi
}

deploy_neuvector "${@}"
