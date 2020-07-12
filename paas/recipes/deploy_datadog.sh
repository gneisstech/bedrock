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
}

deploy_datadog "${@}"
