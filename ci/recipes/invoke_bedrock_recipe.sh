#!/usr/bin/env bash
# usage: invoke_bedrock_recipe.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx DD_CLIENT_API_KEY="${DD_CLIENT_API_KEY:-}"
declare -rx DD_CLIENT_APP_KEY="${DD_CLIENT_APP_KEY:-}"
declare -rx BEDROCK_DEPLOYMENT_CATALOG="${BEDROCK_DEPLOYMENT_CATALOG:-}"
declare -rx BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}"
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-$(pwd)}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function pipeline_env_vars () {
  if is_azure_pipeline_build; then
    env | grep -E "AGENT_|BUILD_|COMMON_|ENDPOINT_|ENVIRONMENT_|PIPELINE_|RESOURCES_|SYSTEM_|TF_BUILD"
  fi
}

function bedrock_invoked_dir () {
  # shellcheck disable=SC2001
  printf '%s' "$(sed -e "s|^$(repo_root)|/src|" <<< "${BEDROCK_INVOKED_DIR}" )"
}

function invoke_bedrock () {
  local -r az_config_dir="${AZURE_CONFIG_DIR:-${HOME}/.azure}"
  docker run \
    --env DD_CLIENT_API_KEY="${DD_CLIENT_API_KEY:-}" \
    --env DD_CLIENT_APP_KEY="${DD_CLIENT_APP_KEY:-}" \
    --env BEDROCK_DEPLOYMENT_CATALOG="${BEDROCK_DEPLOYMENT_CATALOG:-}" \
    --env BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}" \
    --env BEDROCK_INVOKED_DIR="$(bedrock_invoked_dir)" \
    --env-file <(pipeline_env_vars) \
    --volume "$(repo_root):/src" \
    --volume "/var/run/docker.sock:/var/run/docker.sock" \
    --volume "${az_config_dir}:/root/.azure" \
    --volume "${HOME}/.kube:/root/.kube" \
    gneisstech/bedrock_tools:latest \
    "${@}"

#     --volume "${HOME}/.docker:/root/.docker" \
}

function invoke_bedrock_recipe () {
  local -r make_target="${1}"
  SECONDS=0
  pushd "$(repo_root)"
  invoke_bedrock "${@}"
  popd
  "$(repo_root)/ci/recipes/report_metric_to_datadog.sh" "${make_target}" "${SECONDS}"
}

invoke_bedrock_recipe "$@" 2> >(while read -r line; do (echo "LOGGING: $line"); done)
echo
