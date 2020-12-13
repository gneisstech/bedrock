#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_vnet_if_needed.sh public_ip_name

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
declare -rx VNET_NAME="${1}"

function vnet_name (){
    echo "${VNET_NAME}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
    local -r layer="${1}"
    local -r target_recipe="${2}"
    shift 2
    "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function iaas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function vnet_resource_group () {
    iaas_configuration | jq -r -e ".networking.vnets[] | select(.name == \"$(vnet_name)\") | .resource_group"
}

function vnet_cidr () {
    iaas_configuration | jq -r -e ".networking.vnets[] | select(.name == \"$(vnet_name)\") | .cidr"
}

function vnet_already_exists () {
    az network vnet show --name "$(vnet_name)" --resource-group "$(vnet_resource_group)" > /dev/null 2>&1
}

function deploy_vnet () {
    $AZ_TRACE network vnet create \
        --name "$(vnet_name)" \
        --resource-group "$(vnet_resource_group)" \
        --address-prefixes "$(vnet_cidr)"
}

function vnet_subnets () {
    iaas_configuration | jq -r -e ".networking.vnets[] | select(.name == \"$(vnet_name)\") | .subnets"
}

function subnet_count () {
    vnet_subnets | jq -r 'length'
}

function show_subnet () {
    local -r index="${1}"
    vnet_subnets | jq -r ".[${index}]"
}

function subnet_name () {
    local -r index="${1}"
    show_subnet "${index}" | jq -r ".name"
}

function subnet_cidr () {
    local -r index="${1}"
    show_subnet "${index}" | jq -r ".cidr"
}

function deploy_subnet () {
    local -r index="${1}"
    $AZ_TRACE network vnet subnet create \
        --name "$(subnet_name "${index}")" \
        --vnet-name "$(vnet_name)" \
        --resource-group "$(vnet_resource_group)" \
        --address-prefixes "$(subnet_cidr "${index}")"
}

function deploy_subnets () {
    local i
    for i in $(seq 0 $(( $(subnet_count) - 1)) ); do
        deploy_subnet "${i}"
    done
}

function create_vnet () {
    deploy_vnet
    deploy_subnets
}

function create_vnet_if_needed () {
    vnet_already_exists || create_vnet
}

create_vnet_if_needed
