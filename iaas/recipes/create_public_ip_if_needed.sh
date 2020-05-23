#!/usr/bin/env bash
# usage: create_public_ip_if_needed.sh public_ip_name

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
declare -rx PUBLIC_IP_NAME="${1}"

function public_ip_name (){
    echo "${PUBLIC_IP_NAME}"
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

function ip_attr () {
    local -r attr="${1}"
    iaas_configuration | jq -r -e ".networking.public_ip[] | select(.name == \"$(public_ip_name)\") | .${attr}"
}

function public_ip_resource_group () {
    ip_attr 'resource_group'
}

function public_ip_already_exists () {
    az network public-ip show --name  "$(public_ip_name)" --resource-group "$(public_ip_resource_group)" > /dev/null 2>&1
}

function create_public_ip () {
    $AZ_TRACE network public-ip create \
        --name "$(public_ip_name)" \
        --resource-group "$(ip_attr 'resource_group')" \
        --sku "$(ip_attr 'sku')" \
        --allocation-method "$(ip_attr 'allocation_method')" \
        --dns-name "$(public_ip_name)"
}

function create_public_ip_if_needed () {
    public_ip_already_exists || create_public_ip
}

create_public_ip_if_needed
