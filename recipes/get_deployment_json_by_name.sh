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
declare -r BEDROCK_CONFIG_DIR

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function bedrock_config_dir () {
  local bedrock_config_dir="${BEDROCK_CONFIG_DIR:-}"
  if [[ -z "${bedrock_config_dir}" ]]; then
    bedrock_config_dir="$(repo_root)/configuration"
  fi
  printf "%s" "${bedrock_config_dir}"
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(bedrock_config_dir)/deployments/br_deployments.yaml" |
        jq -r -e -c \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

get_deployment_json_by_name "${@}"
