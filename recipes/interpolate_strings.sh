#!/usr/bin/env bash
# usage: interpolate_strings.sh

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

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function process_acr_registry_key () {
    local -r theString="${1}"
    local acr_name rg_name theMessage
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    acr_name="$(jq -r '.registry' <<< "${theMessage}")"
    rg_name="$(jq -r '.resource_group' <<< "${theMessage}")"
    az acr credential show \
        --name "${acr_name}" \
        --resource-group "${rg_name}" \
        2> /dev/null \
    | jq -r -e '.passwords[0].value' \
    || echo "FIXME_PASSWORD"
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function set_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    local -r secret="${3}"
    az keyvault secret set \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        --description 'secure secret from deployment automation' \
        --value "${secret}" \
        2> /dev/null
}

function random_key () {
    hexdump -n 16 -e '"%02X"' /dev/urandom
}

function process_secure_secret () {
    local -r theString="${1}"
    local vault secret_name theMessage secret
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    vault="$(jq -r '.vault' <<< "${theMessage}")"
    secret_name="$(jq -r '.secret_name' <<< "${theMessage}")"
    secret="$(get_vault_secret "${vault}" "${secret_name}")"
    if [[ -z "${secret}" ]]; then
        set_vault_secret "${vault}" "${secret_name}" "$(random_key)" > /dev/null
        secret="$(get_vault_secret "${vault}" "${secret_name}")"
    fi
    if [[ -z "${secret}" ]]; then
        secret="FAKE_SECRET"
    fi
    printf '%s' "${secret}" | sed -e 's|\\|\\\\|g'
}

function process_ip_address () {
    local -r theString="${1}"
    local theMessage ip_resource_id ip_resource public_ip
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    ip_resource_id="$(jq -r '.ip_resource_id' <<< "${theMessage}")"
    ip_resource="$(az resource show --ids "${ip_resource_id}" -o json)"
    public_ip="$(jq -r '.properties.ipAddress' <<< "${ip_resource}")"
    if [[ -z "${public_ip}" ]]; then
        public_ip='FAKE_IP'
    fi
    printf '%s' "${public_ip}"
}

function get_original_cert_from_shared_vault () {
    local -r subscription="${1}"
    local -r vault_name="${2}"
    local -r secret_name="${3}"
    az keyvault secret show \
        --subscription "${subscription}" \
        --vault-name "${vault_name}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function pkcs12_to_pem () {
    base64 --decode | openssl pkcs12 -nodes -in /dev/stdin -passin 'pass:'
}

function fail_empty_set () {
    grep -q '^'
}

function has_intermediate_pem () {
    local -r pem="${1}"
    local -r entrust_certificate_name='Subject:.*CN=Entrust Certification Authority - L1K'
    echo "${pem}" | openssl x509 -noout -text | grep "${entrust_certificate_name}" | fail_empty_set
}

function get_issuer_intermediate_cert_url () {
    openssl x509 -noout -text | grep 'CA Issuers - URI:' | sed -e 's|.*URI:||'
}

function get_intermediate_pem () {
    local -r url="${1}"
    curl -sS "${url}" | openssl x509 -inform der -in /dev/stdin -out /dev/stdout
}

function add_intermediate_certificate () {
    local pem issuer_intermediate_cert_url intermediate_pem
    pem="$(cat /dev/stdin)"
    echo "${pem}"
    if ! has_intermediate_pem "${pem}"; then
        issuer_intermediate_cert_url="$(echo "${pem}" | get_issuer_intermediate_cert_url)"
        intermediate_pem="$(get_intermediate_pem "${issuer_intermediate_cert_url}" )"
        echo "${intermediate_pem}"
    fi
}

function pem_secret () {
    local -r subscription="${1}"
    local -r vault_name="${2}"
    local -r secret_name="${3}"
    get_original_cert_from_shared_vault "${from_subscription}" "${from_vault}" "${from_secret_name}" \
        | pkcs12_to_pem \
        | add_intermediate_certificate
}

function awk_pem_filter () {
    local -r section_id="${1}"
cat <<AWK_TEMPLATE
    BEGIN {echo=0}
    /BEGIN ${section_id}/ { echo=1 }
    echo==1 {print \$0}
    /END ${section_id}/ { echo=0; }
AWK_TEMPLATE
}

function pem_cert () {
    local -r pem_key_cert="${1}"
    awk "$(awk_pem_filter 'CERTIFICATE')" <<< "${pem_key_cert}"
}

function pem_key () {
    local -r pem_key_cert="${1}"
    awk "$(awk_pem_filter 'PRIVATE KEY')" <<< "${pem_key_cert}"
}

function dump_pem_certificate () {
    local -r k8s_namespace="${1}"
    local -r k8s_tls_secret_name="${2}"
    local -r pem_key_cert="${3}"
    printf 'k8s_tls_secret_name=%s\n###\npem_certificate=\n%s\n###\npem_key=\n%s\n' \
        "${k8s_tls_secret_name}" \
        "$(pem_cert "${pem_key_cert}")" \
        "$(pem_key "${pem_key_cert}")"
}

function create_k8s_tls_secret () {
    local -r k8s_namespace="${1}"
    local -r k8s_tls_secret_name="${2}"
    local -r pem_key_cert="${3}"
    # dump_pem_certificate "${k8s_namespace}" "${k8s_tls_secret_name}" "${pem_key_cert}" > /dev/stderr
    kubectl create secret tls \
        --namespace "${k8s_namespace}" \
        "${k8s_tls_secret_name}" \
        --cert=<(pem_cert "${pem_key_cert}") \
        --key=<(pem_key "${pem_key_cert}") > /dev/stderr
}

function process_tls_secret () {
    local -r theString="${1}"
    local theMessage
    local k8s_tls_secret_name k8s_namespace from_vault from_secret_name from_subscription
    theMessage=$(awk 'BEGIN {FS="="} {print $2}' <<< "${theString}")
    k8s_tls_secret_name="$(jq -r '.k8s_tls_secret_name' <<< "${theMessage}")"
    k8s_namespace="$(jq -r '.k8s_namespace' <<< "${theMessage}")"
    from_vault="$(jq -r '.from_vault' <<< "${theMessage}")"
    from_secret_name="$(jq -r '.from_secret_name' <<< "${theMessage}")"
    from_subscription="$(jq -r '.from_subscription' <<< "${theMessage}")"
    pem_key_cert="$(pem_secret "${from_subscription}" "${from_vault}" "${from_secret_name}")"
    result="$(printf 'FIXME_INVALID_TLS_CERTIFICATE [%s]' "${from_secret_name}")"
    if create_k8s_tls_secret "${k8s_namespace}" "${k8s_tls_secret_name}" "${pem_key_cert}"; then
        result="processed_tls_secret"
    fi
    printf '%s' "${result}"
}

function dispatch_functions () {
    declare -a myarray
    (( i=0 ))
    while IFS=$'\n' read -r line_data; do
        local array_entry="${line_data}"
        if (( i % 2 == 1 )); then
            line_data="$( sed -e 's|\\"|"|g' <<< "${line_data}" )"
            case "$line_data" in
                acr_registry_key*)
                    array_entry="$(process_acr_registry_key "${line_data}")"
                    ;;
                secure_secret*)
                    array_entry="$(process_secure_secret "${line_data}")"
                    ;;
                ip_address*)
                    array_entry="$(process_ip_address "${line_data}")"
                    ;;
                tls_secret*)
                    array_entry="$(process_tls_secret "${line_data}")"
                    ;;
                *)
                   array_entry="UNDEFINED_FUNCTION [${line_data}]"
                   ;;
            esac
        fi
        myarray[i]="${array_entry}"
        ((++i))
    done

    (( i=0 ))
    while (( ${#myarray[@]} > i )); do
        printf '%s' "${myarray[i++]}"
    done
}

function interpolate_functions () {
    awk '{gsub(/##/,"\n"); print}' | dispatch_functions
}

function interpolate_strings () {
    declare -a myarray
    (( i=0 ))
    while IFS=$'\n' read -r line_data; do
        local current_line="${line_data}"
        if [[ "${current_line}" =~ '##' ]]; then
            current_line="$(interpolate_functions <<< "${current_line}")"
        fi
        printf '%s\n' "${current_line}"
    done
}

interpolate_strings