#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml purge_environment.sh

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
declare -x AZ_TRACE

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
  local -r layer="${1}"
  local -r target_recipe="${2}"
  shift 2
  "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function init_trace () {
    if [[ -z "${AZ_TRACE}" ]]; then
        export AZ_TRACE="echo az"
    fi
}

function target_config () {
    printf '%s' "${TARGET_CONFIG}"
}

function target_subscription () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.metadata.azure.default.subscription'
}

function set_subscription () {
    local -r desired_subscription="${1}"
    az account set --subscription "${desired_subscription}"
}

function set_target_subscription () {
    set_subscription "$(target_subscription)"
}

function current_azure_subscription () {
    az account show -o json | jq -r -e '.id'
}

function purge_environment () {
    local saved_subscription
    date
    saved_subscription="$(current_azure_subscription)"
    set_target_subscription
    init_trace
    invoke_layer 'iaas' 'purge_resource_groups'
    invoke_layer 'paas' 'purge_key_vaults'
    set_subscription "${saved_subscription}"
    date
}

purge_environment
