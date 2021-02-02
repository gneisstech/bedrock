#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_dns_zone_if_needed.sh dns_a_zone_record_set

#
# Maintainer: techguru@byiq.com
#
# Copyright (c) 2017-2020,  Cloud Scaling -- All Rights Reserved
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
declare -rx TARGET_CONFIG
declare -rx AZ_TRACE

# Arguments
# ---------------------
declare -rx DNS_ZONE_NAME="${1}"

function dns_zone_name() {
  echo "${DNS_ZONE_NAME}"
}

function repo_root() {
  git rev-parse --show-toplevel
}

function invoke_layer() {
  local -r layer="${1}"
  local -r target_recipe="${2}"
  shift 2
  "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config() {
  printf '%s' "${TARGET_CONFIG}"
}

function iaas_configuration() {
  yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function dns_zone_attr() {
  local -r attr="${1}"
  iaas_configuration | jq -r -e ".networking.dns_zones[] | select(.name == \"$(dns_zone_name)\") | .${attr}"
}

function create_dns_zone() {
  $AZ_TRACE network dns zone create \
    --name "$(dns_zone_name)" \
    --resource-group "$(dns_zone_attr 'resource_group')" \
    --subscription "$(dns_zone_attr 'subscription')"
}

function update_dns_zone() {
  $AZ_TRACE network dns zone update \
    --name "$(dns_zone_name)" \
    --resource-group "$(dns_zone_attr 'resource_group')" \
    --subscription "$(dns_zone_attr 'subscription')"
}

function dns_zone_exists() {
  az network dns zone show \
    --name "$(dns_zone_name)" \
    --resource-group "$(dns_zone_attr 'resource_group')" \
    --subscription "$(dns_zone_attr 'subscription')" \
  > /dev/null 2>&1
}

function create_dns_zone_if_needed() {
  if dns_zone_exists; then
    update_dns_zone
  else
    create_dns_zone
  fi
}

create_dns_zone_if_needed
