#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_server_farm_if_needed.sh server_farm_name

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
declare -rx SERVER_FARM_NAME="${1}"

function server_farm_name (){
    echo "${SERVER_FARM_NAME}"
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

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function plan_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".server_farms[] | select(.name == \"$(server_farm_name)\") | .${attr}"
}

function server_farm_resource_group () {
    plan_attr 'resource_group'
}

function fail_empty_set () {
    grep -q '^'
}

function server_farm_already_exists () {
    az appservice plan show \
        --name "$(server_farm_name)" \
        --resource-group "$(server_farm_resource_group)" \
        2> /dev/null \
    | fail_empty_set
}

function linux_option_if_needed () {
    if [[ "true" == "$(plan_attr 'is_linux')" ]]; then
        echo "--is-linux"
    fi
}

function deploy_server_farm () {
    #  shellcheck disable=SC2046
    $AZ_TRACE appservice plan create \
        --name "$(server_farm_name)" \
        --resource-group "$(server_farm_resource_group)" \
        "$(linux_option_if_needed)" \
        --number-of-workers "$(plan_attr 'number_of_workers')" \
        --sku "$(plan_attr 'sku')"
}

function create_server_farm_if_needed () {
    server_farm_already_exists || deploy_server_farm
}

create_server_farm_if_needed

