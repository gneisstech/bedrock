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

function dns_a_record_public_ip_name () {
    iaas_configuration | \
        jq -r -e ".networking.dns_a_records[] | select(.host == \"$(dns_a_record_host)\") | .a_record_public_ip"
}

function public_ip_resource_group () {
    iaas_configuration | \
        jq -r -e ".networking.public_ip[] | select(.name == \"$(dns_a_record_public_ip_name)\") | .resource_group"
}

function public_ip_info () {
    az network public-ip show \
        --name  "$(dns_a_record_public_ip_name)" \
        --resource-group "$(public_ip_resource_group)" \
        2> /dev/null \
    || echo '{"ipAddress" : "ipv4.invalid"}'
}

function extract_ipv4_from_public_ip () {
    public_ip_info | jq -r '.ipAddress'
}

function get_ipv4_address_for_public_ip () {
    extract_ipv4_from_public_ip || echo "reference_to[$(dns_a_record_public_ip_name)]"
}

function create_dns_a_record () {
    echo az network dns record-set a create \
        --name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)" \
        --if-none-match \
        -ttl "$(dns_a_record_ttl)"
    echo az network dns record-set a add-record \
        --ipv4-address "$(get_ipv4_address_for_public_ip)" \
        --record-set-name "$(dns_a_record_host)" \
        --resource-group "$(dns_a_record_resource_group)" \
        --zone-name "$(dns_a_record_zone)"
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
