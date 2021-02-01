#!/usr/bin/env bash
# usage: get_target_config_path.sh

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

function get_target_config_filename () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.config' <<< "${deployment_json}"
}

function bedrock_config_environment_dir () {
  local config_dir="${BEDROCK_CONFIG_DIR:-}"
  if [[ -z "${config_dir}" ]]; then
    config_dir="$(repo_root)/configuration/environments"
  fi
  printf "%s" "${config_dir}"
}

function get_target_config_path () {
    local -r deployment_json="${1}"
    printf "%s/%s" "$(bedrock_config_environment_dir)" "$(get_target_config_filename "${deployment_json}")"
}

get_target_config_path "${@}"
