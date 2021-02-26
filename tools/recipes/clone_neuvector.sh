#!/usr/bin/env bash
# usage: clone_neuvector.sh
# place copy of containers in our Azure repo(s) for reliability in pull

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"
declare -rx DD_SECRET_VAULT="${DD_SECRET_VAULT:-/src}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function get_vault_secret() {
  local -r vault="${1}"
  local -r secret_name="${2}"
  az keyvault secret show \
    --vault-name "${vault}" \
    --name "${secret_name}" \
    2>/dev/null |
    jq -r '.value'
}

function get_docker_token() {
  get_vault_secret "${DD_SECRET_VAULT}" 'docker-token'
}

function get_docker_user() {
  get_vault_secret "${DD_SECRET_VAULT}" 'docker-user'
}

function acr_registries() {
  local -r app="${1}"
  printf '%sdevregistry\n' "${app}"
  printf '%sqaregistry\n' "${app}"
  printf '%sprodregistry\n' "${app}"
}

function acr_logins() {
  local -r app="${1}"
  acr_registries "${app}" | xargs -n 1 -r az acr login -n
}

function neuvector_containers() {
  # @@ TODO replace with neuvector chart managed by Bedrock
  grep 'repository:' "${BEDROCK_INVOKED_DIR}/configuration/k8s/charts/neuvector-helm/values.yaml" | sed -e 's|.* ||'
}

function get_app() {
  local -r deployment_json="${1}"
  jq -r -e '.environment.app' <<<"${deployment_json}"
}

function get_deployment_json_by_name() {
  local -r deployment_name="${1}"
  "/bedrock/recipes/get_deployment_json_by_name.sh" "${deployment_name}"
}

function clone_neuvector() {
  local -r deployment_name="${1}"
  local deployment_json
  deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
  local app containersa
  app="$(get_app "${deployment_json}")"
  containers="$(neuvector_containers)"
  printf 'containers [%s]\n' "${containers}"
  acr_logins "${app}"
  get_docker_token | docker login --username "$(get_docker_user)" --password-stdin
  for image in ${containers}; do
    local originPath targetPath targetRepo
    originPath="${image}"
    docker pull "${originPath}" || continue
    #shellcheck disable=SC2043
    for targetRepo in $(acr_registries "${app}"); do
      local targetPath
      targetPath="${targetRepo}.azurecr.io/${image}"
      docker tag "${originPath}" "${targetPath}" || continue
      docker push "${targetPath}" || continue
    done
  done
}

clone_neuvector "$@"
