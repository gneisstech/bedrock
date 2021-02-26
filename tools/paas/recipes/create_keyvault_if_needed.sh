#!/usr/bin/env bash
# usage: create_keyvault_if_needed.sh ResourceGroupName KeyVaultName

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

# Arguments
# ---------------------
declare -rx KEYVAULT_NAME="${1}"
declare -rx RESOURCE_GROUP_NAME="fake_name"

function repo_root () {
    git rev-parse --show-toplevel
}

function target_config () {
    printf '%s' "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function keyvault_name () {
    printf '%s' "${KEYVAULT_NAME}"
}

function get_keyvault_rg () {
    paas_configuration | jq -r -e ".keyvaults[] | select ( .name == \"$(keyvault_name)\" ) | .resource_group"
}

function get_purge () {
    paas_configuration | jq -r -e ".keyvaults[] | select ( .name == \"$(keyvault_name)\" ) | .purge"
}

function keyvault_already_exists () {
    az keyvault show --name "$(keyvault_name)" --resource-group "$(get_keyvault_rg)" > /dev/null 2>&1
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function get_azure_pipeline_sp_id () {
    env | grep 'SPNOBJECTID=' | sed -e 's/.*=//'
}

function get_azure_pipeline_sp_info () {
    az ad sp show --id "$(get_azure_pipeline_sp_id)"
}

function get_azure_pipeline_app_id () {
    get_azure_pipeline_sp_info | jq -r -e '.appId'
}

function assign_list_get_set_policy_if_needed () {
    if is_azure_pipeline_build; then
        $AZ_TRACE keyvault set-policy \
            --name "$(keyvault_name)" \
            --spn "$(get_azure_pipeline_app_id)" \
            --secret-permissions get list set
    fi
}

function create_keyvault () {
    $AZ_TRACE keyvault create \
        --name "$(keyvault_name)" \
        --resource-group "$(get_keyvault_rg)" \
        --enabled-for-template-deployment
}

function create_keyvault_if_needed () {
    keyvault_already_exists || create_keyvault
    assign_list_get_set_policy_if_needed
}

create_keyvault_if_needed
