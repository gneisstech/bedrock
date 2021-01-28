#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml deploy_saas.sh

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

function saas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function service_names () {
    local -r service_group="${1}"
    saas_configuration | jq -r -e "[.${service_group}.services[]? | select(.action == \"create\") | .name ] | @tsv // null"
}

function deploy_services () {
    local -r service_group="${1}"
    local service_name
    for service_name in $(service_names "${service_group}"); do
        invoke_layer 'saas' 'create_service_if_needed' "${service_name}" "${service_group}"
    done
}

function application_gateway_names () {
    saas_configuration | jq -r -e '[.application_gateways[]? | select(.action == "preserve") | .name ] | @tsv // null'
}

function deploy_application_gateways () {
    local gateway_name
    for gateway_name in $(application_gateway_names); do
        invoke_layer 'saas' 'create_application_gateway_if_needed' "${gateway_name}"
    done
}

function apply_service_access_restrictions () {
    local -r service_group="${1}"
    local service_name
    for service_name in $(service_names "${service_group}"); do
        invoke_layer 'saas' 'apply_service_access_restrictions' "${service_name}" "${service_group}"
    done
}

function register_application () {
    local -r service_group="${1}"
    invoke_layer 'saas' 'register_application_if_needed' "${service_group}"
}

function deploy_saas () {
    deploy_services 'authn_services'
    deploy_services 'web_services'
    deploy_application_gateways
    apply_service_access_restrictions 'authn_services'
    apply_service_access_restrictions 'web_services'
    register_application 'application_registration'
}

deploy_saas
