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
declare -rx BEDROCK_INVOKED_DIR

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function get_target_config_filename () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.config' <<< "${deployment_json}"
}

function bedrock_config_environmenst_dir () {
  printf "%s/configuration/environments" "${BEDROCK_INVOKED_DIR}"
}

function get_target_config_path () {
    local -r deployment_json="${1}"
    printf "%s/%s" "$(bedrock_config_environments_dir)" "$(get_target_config_filename "${deployment_json}")"
}

get_target_config_path "${@}"
