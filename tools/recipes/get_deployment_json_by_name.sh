#!/usr/bin/env bash
# usage: get_deployment_json_by_name.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-.}"
declare -rx BEDROCK_DEPLOYMENT_CATALOG="${BEDROCK_DEPLOYMENT_CATALOG:-br_deployments.yaml}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function bedrock_config_deployments_dir () {
  printf "%s/configuration/deployments" "${BEDROCK_INVOKED_DIR:-}"
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(bedrock_config_deployments_dir)/${BEDROCK_DEPLOYMENT_CATALOG}" |
        jq -r -e -c \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

get_deployment_json_by_name "${@}"
