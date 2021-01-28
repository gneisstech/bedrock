#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_azure_disk_volume_if_needed.sh azure_disk_volume

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
declare -rx TARGET_CONFIG
declare -rx AZ_TRACE

# Arguments
# ---------------------
declare -rx kubernetes_cluster_NAME="${1}"

function kubernetes_cluster_name (){
    echo "${kubernetes_cluster_NAME}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
    local -r layer="${1}"
    local -r target_recipe="${2}"
    shift 2
    "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    printf '%s/%s' "$(repo_root)" "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function azure_disk_volume_json () {
    local -r volume_name="${1}"
    jq -r -e --arg volume_name "${volume_name}" '.storage.azure_disks[]? | select(.name | test($volume_name))'
}

function azure_disk_volume_exists () {
    local volume_name_json="${1}"
    az disk show \
        --name "$(jq -r -e '.name' <<< "${volume_name_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${volume_name_json}" )" \
        2> /dev/null \
    || false
}

function dv_attr () {
    local -r attr="${1}"
    jq -r -e ".${attr}"
}

function dv_attr_size () {
    local -r attr="${1}"
    jq -r -e ".${attr} | length // 0"
}

function disk_volume_zone_option_if_present () {
    local volume_name_json="${1}"
    local -r option_key="${2}"
    local -r option_config="${3}"
    if [[ '0' != "$(dv_attr_size "${option_config}" <<< "${volume_name_json}")" ]]; then
        printf -- "--%s %s" "${option_key}" "$(dv_attr "${option_config}" <<< "${volume_name_json}")"
    fi
    true
}

function update_azure_disk_volume () {
    local volume_name_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE disk update \
        --name "$(jq -r -e '.name' <<< "${volume_name_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${volume_name_json}" )" \
        --size-gb "$(jq -r -e '.size_gb' <<< "${volume_name_json}" )" \
        --encryption-type "$(jq -r -e '.encryption_type' <<< "${volume_name_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${volume_name_json}" )"
}

function create_azure_disk_volume () {
    local volume_name_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE disk create \
        --name "$(jq -r -e '.name' <<< "${volume_name_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${volume_name_json}" )" \
        --location "$(jq -r -e '.location' <<< "${volume_name_json}" )" \
        --os-type "$(jq -r -e '.os_type' <<< "${volume_name_json}" )" \
        --size-gb "$(jq -r -e '.size_gb' <<< "${volume_name_json}" )" \
        --encryption-type "$(jq -r -e '.encryption_type' <<< "${volume_name_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${volume_name_json}" )" \
        --tags "$(jq -r -e '.tags' <<< "${volume_name_json}" )" \
        $(disk_volume_zone_option_if_present "${volume_name_json}" 'zone' 'zone')
}

function create_or_update_azure_disk_volume () {
    local volume_name_json="${1}"
    if azure_disk_volume_exists "${volume_name_json}"; then
        update_azure_disk_volume "${volume_name_json}"
    else
        create_azure_disk_volume "${volume_name_json}"
    fi
}

function get_volume_configuration_json () {
  local volume_name="${1}"
  paas_configuration \
  | azure_disk_volume_json "${volume_name}" \
  | "/bedrock/recipes/join_string_arrays.sh"
}

function create_azure_disk_volume_if_needed () {
    local -r volume_name="${1}"
    local volume_name_json
    volume_name_json="$(get_volume_configuration_json "${volume_name}")"
    printf 'Creating or Updating Az Disk Volume [%s]\n' "${volume_name}" > /dev/stderr
    create_or_update_azure_disk_volume "${volume_name_json}"
}

create_azure_disk_volume_if_needed "$@"
