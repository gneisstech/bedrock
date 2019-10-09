#!/usr/bin/env bash
# usage: create_dns_a_record_if_needed.sh dns_a_record_host

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
    "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function iaas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function dns_a_record_zone () {
    iaas_configuration | jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .zone"
}

function dns_a_record_already_exists () {
    az network dns record-set a show \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        > /dev/null 2>&1
}

function dns_a_record_resource_group () {
    iaas_configuration | \
        jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .resource_group"
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
    echo "/subscriptions/${subscription}/resourceGroups/${rg}/providers/Microsoft.Network/publicIPAddresses/${pip}"
}

function create_dns_a_record () {
    $AZ_TRACE network dns record-set a create \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --target-resource "$(dns_target_resource)" \
        --if-none-match \
        --ttl "$(dns_a_record_ttl)"
}

function dns_zone_exists () {
    az network dns zone show \
        --name "$(dns_a_record_zone)" \
        --resource-group "$(dns_a_record_resource_group)" \
        > /dev/null 2>&1
}

function create_dns_a_record_if_needed () {
    dns_zone_exists && (dns_a_record_already_exists || create_dns_a_record)
}

create_dns_a_record_if_needed
