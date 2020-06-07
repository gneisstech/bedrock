#!/usr/bin/env bash
# usage: deploy_environment.sh target_environment_config.yaml

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
    "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function saas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function keyvault_names () {
    paas_configuration | jq -r -e '[.keyvaults[]? | select(.action == "create") | .name ] | @tsv'
}

function deploy_keyvaults () {
    local keyvault_name
    for keyvault_name in $(keyvault_names); do
        invoke_layer 'paas' 'create_keyvault_if_needed' "${keyvault_name}"
    done
}

function seeded_secret_names () {
    saas_configuration | jq -r -e '[.helm.default_values.secrets.seed_values[]? | .dest ] | @tsv'
}

function seed_secrets () {
    local secret_name
    for secret_name in $(seeded_secret_names); do
        invoke_layer 'paas' 'seed_secret_if_needed' "${secret_name}"
    done
}

function service_principal_names () {
    paas_configuration | jq -r -e '[.service_principals[]? | select(.action == "create") | .name ] | @tsv'
}

function deploy_service_principals () {
    local service_principal_name
    for service_principal_name in $(service_principal_names); do
        invoke_layer 'paas' 'create_service_principal_if_needed' "${service_principal_name}"
    done
}

function database_server_names () {
    paas_configuration | jq -r -e '[.databases.servers[]? | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_database_servers () {
    local server_name
    for server_name in $(database_server_names); do
        invoke_layer 'paas' 'create_database_server_if_needed' "${server_name}"
    done
}

function database_instance_names () {
    paas_configuration | jq -r -e '[.databases.instances[]? | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_database_instances () {
    local instance_name
    for instance_name in $(database_instance_names); do
        invoke_layer 'paas' 'create_database_instance_if_needed' "${instance_name}"
    done
}

function deploy_databases () {
    deploy_database_servers
    deploy_database_instances
}

function server_farm_names () {
    paas_configuration | jq -r -e '[.server_farms[]? | select(.action == "create") | .name ] | @tsv'
}

function deploy_server_farms () {
    local farm_name
    for farm_name in $(server_farm_names); do
        invoke_layer 'paas' 'create_server_farm_if_needed' "${farm_name}"
    done
}

function container_registry_names () {
    paas_configuration | jq -r -e '[.container_registries[]? | select(.action == "create") | .name ] | @tsv'
}

function deploy_container_registries () {
    local registry_name
    for registry_name in $(container_registry_names); do
        invoke_layer 'paas' 'create_container_registry_if_needed' "${registry_name}"
    done
}

function virtual_machine_names () {
    paas_configuration | jq -r -e '[.virtual_machines[]? | select(.action == "preserve") | .name ] | @tsv'
}

function deploy_virtual_machines () {
    local machine_name
    for machine_name in $(virtual_machine_names); do
        invoke_layer 'paas' 'create_virtual_machine_if_needed' "${machine_name}"
    done
}

function kubernetes_cluster_names () {
    paas_configuration | jq -r -e '[.k8s.clusters[]? | select(.action == "create") | .name ] | @tsv'
}

function deploy_kubernetes_clusters () {
    local cluster_name
    for cluster_name in $(kubernetes_cluster_names); do
        invoke_layer 'paas' 'create_kubernetes_cluster_if_needed' "${cluster_name}"
    done
}

function deploy_paas () {
    deploy_keyvaults
    seed_secrets
    deploy_service_principals
    deploy_databases
    deploy_server_farms
    deploy_container_registries
    deploy_virtual_machines
    deploy_kubernetes_clusters
}

deploy_paas
