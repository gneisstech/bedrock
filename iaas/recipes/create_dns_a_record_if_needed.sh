#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_dns_a_record_if_needed.sh dns_a_record_host

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
declare -rx DNS_A_RECORD_HOST="${1}"

function dns_a_record_host (){
    echo "${DNS_A_RECORD_HOST}"
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

function iaas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function dns_a_record_attr () {
    local -r attr="${1}"
    iaas_configuration | jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .${attr}"
}

function dns_a_record_resource_group () {
    dns_a_record_attr 'resource_group'
}

function dns_a_record_zone () {
    dns_a_record_attr 'zone'
}

function dns_a_record_subscription () {
    dns_a_record_attr 'subscription'
}

function dns_a_record_already_exists () {
    az network dns record-set a show \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        > /dev/null 2>&1
}

function dns_a_record_ttl () {
    iaas_configuration | \
        jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .a_record_ttl"
}

function public_ip_name () {
    iaas_configuration | \
        jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .a_record_public_ip"
}

function public_ip_resource_group () {
    iaas_configuration | \
        jq -r -e ".networking.public_ip[] | select(.name == \"$(public_ip_name)\") | .resource_group"
}

function public_ip_subscription () {
    iaas_configuration | \
        jq -r -e ".networking.public_ip[] | select(.name == \"$(public_ip_name)\") | .subscription"
}

function dns_target_resource () {
    local subscription rg pip
    subscription="$(public_ip_subscription)"
    rg="$(public_ip_resource_group)"
    pip="$(public_ip_name)"
    printf '/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/publicIPAddresses/%s' "${subscription}" "${rg}" "${pip}"
}

function create_dns_a_record () {
    $AZ_TRACE network dns record-set a create \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        --target-resource "$(dns_target_resource)" \
        --if-none-match \
        --ttl "$(dns_a_record_ttl)"
}

function update_dns_a_record () {
    $AZ_TRACE network dns record-set a update \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        --target-resource "$(dns_target_resource)"
}

function dns_zone_exists () {
    az network dns zone show \
        --name "$(dns_a_record_zone)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --subscription "$(dns_a_record_subscription)" \
        > /dev/null 2>&1
}

function dns_caa_record_already_exists () {
    az network dns record-set caa show \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        > /dev/null 2>&1
}

function create_dns_caa_record () {
    $AZ_TRACE network dns record-set caa add-record \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        --if-none-match \
        --ttl "$(dns_a_record_ttl)" \
        --record-set-name "$(dns_a_record_host)" \
        --flags '0' \
        --tag 'issue' \
        --value 'letsencrypt.org'
}

function update_dns_caa_record () {
    $AZ_TRACE network dns record-set caa update \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --subscription "$(dns_a_record_subscription)" \
        --if-none-match '*' \
        --name "$(dns_a_record_host)"
}

function create_dns_caa_record_if_needed () {
  if dns_caa_record_already_exists; then
      update_dns_caa_record || true
  else
      create_dns_caa_record
  fi
}

function create_dns_a_record_if_needed () {
    if dns_zone_exists; then
        create_dns_caa_record_if_needed
        if dns_a_record_already_exists; then
            update_dns_a_record
        else
            create_dns_a_record
        fi
    fi
}

create_dns_a_record_if_needed
