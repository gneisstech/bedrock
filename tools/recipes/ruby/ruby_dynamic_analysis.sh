#!/usr/bin/env bash
# usage: ruby_dynamic_analysis.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfdevregistry}"
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"
declare -rx IMAGENAME="${IMAGENAME:-cf-elm-web-api-docker}"

# Arguments
# ---------------------


function repo_root () {
    git rev-parse --show-toplevel
}

function get_helm_chart_name() {
  ls "${BEDROCK_INVOKED_DIR}/helm"
}

function get_helm_values_file_name() {
  printf "%s/helm/%s/values.yaml" "${BEDROCK_INVOKED_DIR}" "$(get_helm_chart_name)"
}

function read_helm_values_as_json() {
  yq eval-all --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function ruby_dynamic_analysis () {
  local container_path
  container_path="$(get_docker_repo_name):bedrock"
  local db_container_id
    db_container_id="$(docker run \
        --rm \
        -e 'ACCEPT_EULA=Y' \
        -e 'SA_PASSWORD=xyzzy2XYZZY' \
        -p 127.0.0.1:1433:1433 \
        -d \
        mcr.microsoft.com/mssql/server:2017-latest)"
  container_host="$(docker inspect "${db_container_id}" | jq -r '.[].NetworkSettings.IPAddress')"
  docker run \
      --rm \
      -e 'RAILS_ENV=test' \
      -e 'CUSTOMCONNSTR_SERVICE_PRINCIPAL_SECRET=xyzzy2XYZZY' \
      -e "DATABASE_HOST=${container_host}" \
      -e 'SQL_SERVER_DEV_PASSWORD=xyzzy2XYZZY' \
      "${container_path}" \
      /assets/run_ruby_dynamic_analysis.sh
}

ruby_dynamic_analysis
