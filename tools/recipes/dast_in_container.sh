#!/usr/bin/env bash

#
# Maintainer: techguru@byiq.com
#
# Copyright (c) 2017-2019,  Cloud Scaling -- All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BEDROCK_INVOKED_DIR="${BEDROCK_INVOKED_DIR:-/src}"

# Arguments
# ---------------------

function repo_root() {
  git rev-parse --show-toplevel
}

function fail_empty_set () {
    grep -q '^'
}

function get_helm_chart_name() {
  ls "${BEDROCK_INVOKED_DIR}/helm"
}

function get_helm_values_file_name() {
  printf "%s/helm/%s/values.yaml" "${BEDROCK_INVOKED_DIR}" "$(get_helm_chart_name)"
}

function read_helm_values_as_json() {
  yq r --tojson "$(get_helm_values_file_name)"
}

function get_docker_repo_name() {
  read_helm_values_as_json | jq -r -e '.image.repository'
}

function docker_entry_cmd() {
  local -r container_path="${1}"
  docker inspect -f '{{ .Config.Cmd}}' "${container_path}"
}

function docker_container_has_ruby() {
  local -r container_path="${1}"
  docker_entry_cmd "${container_path}" | grep "ruby" | fail_empty_set
}

function dast_in_container() {
  local container_path
  container_path="$(get_docker_repo_name):bedrock"
  if docker_container_has_ruby "${container_path}"; then
    /bedrock/recipes/ruby/ruby_dynamic_analysis.sh
  else
    true
  fi
}

dast_in_container
