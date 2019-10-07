#!/usr/bin/env bash
# usage: deploy_environment.sh target_environment_config.yaml

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx TARGET_CONFIG

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
  local -r layer="${1}"
  local -r target_recipe="${2}"
  shift 2
  "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function deploy_environment () {
    #invoke_layer 'iaas' 'deploy_iaas'
    #invoke_layer 'paas' 'deploy_paas'
    invoke_layer 'saas' 'deploy_saas'
}

deploy_environment
