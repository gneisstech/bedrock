#!/usr/bin/env bash
# usage: bless_development_artifacts.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx HOST_HOME="${HOST_HOME:-}"
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"
declare -rx BEDROCK_CLUSTER="${BEDROCK_CLUSTER:-}"
declare -rx BUILD_BUILDNUMBER="${BUILD_BUILDNUMBER:-}"
declare -rx BUILD_DEFINITIONNAME="${BUILD_DEFINITIONNAME:-}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function get_helm_chart_name() {
  ls "${BEDROCK_INVOKED_DIR}/helm"
}

function get_helm_values_file_name() {
  printf "%s/helm/%s/values.yaml" "${BEDROCK_INVOKED_DIR}" "$(get_helm_chart_name)"
}

function read_helm_values_as_json () {
  yq eval-all --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function get_docker_registry_host() {
  get_docker_repo_name | sed -e 's|\/.*||'
}

function get_docker_registry_name() {
  get_docker_registry_host | sed -e 's|\..*||'
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function get_project_prefix() {
  if [[ "${BEDROCK_CLUSTER}" == "" ]]; then
    get_helm_chart_name | sed -e 's|-.*||'
  else
    printf '%s' "${BEDROCK_CLUSTER}" | sed -e 's|_.*||' | tr '[:upper:]' '[:lower:]'
  fi
}

function get_project_prefix_uc() {
  get_project_prefix | tr '[:lower:]' '[:upper:]'
}

function get_devops_vault() {
  printf '%s-devops-kv' "$(get_project_prefix)"
}

function get_go_shared_module_private_key() {
  get_vault_secret "$(get_devops_vault)" 'go-shared-modules-private-key'
}

function create_private_key_file() {
  get_go_shared_module_private_key | base64 -d > ~/.ssh/id_go_shared_module
  chmod 600 ~/.ssh/id_go_shared_module
}

function public_key_value() {
  echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4+3ECGASdmMlcWX9dW/7AYBgmEK2UkNGh3J6L1pmBXoIe1nIoRldY23jv41G8zpO/88mUe4aPpqVLJEbVZOz8FN7EzUYEZXyKSgXYlh9gxdpVAMmSoTaPIJq6IwHw0OL0BE/HhyaYqONZSZr2er76q5t7Iy6RNKPkAY2YEINflPF9tMvZaUQaQoQ6WoDMxbyqGqrYTfXKROsbI27RRi5YZ5Nru3Urv/pUYWivUlJwMsF6dHXmKPc7Z8VR+c+4yPkVapYNH3AQMZh6ixIQIZ2Hiuo87ldXu6uthpc1DHoPTrCN3im0W5b6K6zmyFJ+nV8cxpQSL9xuilUkN/Abb3OFR4a0GvrNbyyeEe2gWCJVSiLoPQMN+LQAG0o4L97BXTkXu5a+HMwZOd3ZKb09WpV5Fe7bCWeIoVDpqGNc2QFUUq+lZ7AfpJxYeJtGXlNSPXCc11r9Hj3NE6g2OnBIw2Lp5icT8yrNu20ufPMV7PVvP+NM2SCSuz/eiIrfMjXg8Yycxd46N5TDfngrBmmAj/FORIrJW8eNsPuil0V48juCRdZSFGFR8UQbolq6xMe53v73CJD7z2oZ5zMNn3jA1hD+6z1YZbZeE0HL96QDnEFcIl58qt/AMPE0A5Kvywr7QxFHZ7/ia0+EEumnLknRu5Li9C9AizqE/2OFfuDcWYjj5w== techguru@byiq.com'
}

function create_public_key_file() {
  public_key_value > ~/.ssh/id_go_shared_module.pub
}

function vsts_host_signature() {
  echo 'vs-ssh.visualstudio.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H'
}

function register_known_host() {
  vsts_host_signature >> ~/.ssh/known_hosts
}

function setup_ssh() {
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  eval "$(ssh-agent -s)"
  create_private_key_file
  create_public_key_file
  register_known_host
  ssh-add ~/.ssh/id_go_shared_module
  ssh-add -l
}

function get_bd_token() {
  get_vault_secret "$(get_devops_vault)" 'bd-token'
}

function get_bd_url() {
  get_vault_secret "$(get_devops_vault)" 'bd-url'
}

function attach_docker_registry () {
  az acr login -n "$(get_docker_registry_name)"
}

function install_dotnet() {
  curl -L https://dot.net/v1/dotnet-install.sh -o ./dotnet-install.sh
  source ./dotnet-install.sh
  printf '%s\n' "$(command -v dotnet)"
}

function blackduck_scanner() {
  local -r base_shared_tools_dir="${HOST_HOME}/.bedrock/ci_pipeline_home"

  attach_docker_registry
  setup_ssh
  git config --global --replace-all url.git+ssh://ablcode@vs-ssh.visualstudio.com/v3/ablcode.insteadof https://ablcode.visualstudio.com

  install_dotnet
  java -version
  docker image ls --all

  bash <(curl -s -L https://detect.synopsys.com/detect.sh) \
    --logging.level.com.synopsys.integration=DEBUG \
    --detect.ignore.connection.failures=true \
    --detect.output.path="${base_shared_tools_dir}/blackduck" \
    --detect.blackduck.signature.scanner.individual.file.matching=ALL \
    --detect.blackduck.signature.scanner.dry.run=false \
    --blackduck.api.token="$(get_bd_token)" \
    --blackduck.url="$(get_bd_url)" \
    --cleanup.inspector.container=false \
    --detect.blackduck.signature.scanner.paths="${base_shared_tools_dir}/scanners" \
    --detect.blackduck.signature.scanner.exclusion.pattern.search.depth=100 \
    --detect.project.name="$(get_project_prefix_uc)-${BUILD_DEFINITIONNAME}" \
    --detect.project.version.name="${BUILD_BUILDNUMBER}" \
    --detect.docker.image="$(get_docker_repo_name):bedrock"

    docker image ls --all
}

blackduck_scanner "$@"
