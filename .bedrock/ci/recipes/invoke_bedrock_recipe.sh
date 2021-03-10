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
declare -rx DD_SECRET_VAULT="${DD_SECRET_VAULT:-}"
declare -rx BEDROCK_DEPLOYMENT_CATALOG="${BEDROCK_DEPLOYMENT_CATALOG:-}"
declare -rx BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}"
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-$(pwd)}"
declare -rx BEDROCK_SERVICE="${BEDROCK_SERVICE:-}"
declare -rx DOCKERFILE="${DOCKERFILE:-Dockerfile}"
declare -rx HOST_HOME="${HOST_HOME:-$(pwd)}"

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
    env | grep -E "AGENT_|BUILD_|COMMON_|ENDPOINT_|ENVIRONMENT_|PIPELINE_|RESOURCES_|SYSTEM_|TF_BUILD|BEDROCK_"
  fi
}

function bedrock_invoked_dir () {
  # shellcheck disable=SC2001
  printf '%s' "$(sed -e "s|^$(repo_root)|/src|" <<< "${BEDROCK_INVOKED_DIR}" )"
}

function invoke_bedrock () {
  local -r az_config_dir="${AZURE_CONFIG_DIR:-${HOME}/.azure}"
  docker run \
    --rm \
    --env DD_SECRET_VAULT="${DD_SECRET_VAULT:-}" \
    --env BEDROCK_DEPLOYMENT_CATALOG="${BEDROCK_DEPLOYMENT_CATALOG:-}" \
    --env BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}" \
    --env BEDROCK_INVOKED_DIR="$(bedrock_invoked_dir)" \
    --env BEDROCK_SERVICE="${BEDROCK_SERVICE:-}" \
    --env DOCKERFILE="${DOCKERFILE:-Dockerfile}" \
    --env HOST_HOME="${HOST_HOME:-$(pwd)}" \
    --env-file <(pipeline_env_vars) \
    --volume "$(repo_root):/src" \
    --volume "/var/run/docker.sock:/var/run/docker.sock" \
    --volume "${az_config_dir}:/root/.azure" \
    --volume "${HOME}/.kube:/root/.kube" \
    gneisstech/bedrock_tools:latest \
    "${@}"
}

function invoke_bedrock_recipe () {
  local -r make_target="${1}"
  SECONDS=0
  pushd "$(repo_root)" 1> /dev/null 2>&1
  invoke_bedrock "${@}"
  popd 1> /dev/null 2>&1
  "${BEDROCK_INVOKED_DIR}/.bedrock/ci/recipes/report_metric_to_datadog.sh" "${make_target}" "${SECONDS}"
}

invoke_bedrock_recipe "$@" 2> >(while read -r line; do (echo "LOGGING: $line"); done)
