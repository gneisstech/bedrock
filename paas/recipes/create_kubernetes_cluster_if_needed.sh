#!/usr/bin/env bash
# usage: create_kubernetes_cluster_if_needed.sh kubernetes_cluster_name

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
declare -rx kubernetes_cluster_NAME="${1}"

function kubernetes_cluster_name (){
    echo "${kubernetes_cluster_NAME}"
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

function k8s_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".k8s.clusters[] | select(.name == \"$(kubernetes_cluster_name)\") | .${attr}"
}

function k8s_string () {
    local -r attr="${1}"
    local -r key="${2}"
    k8s_attr "${attr}" | jq -r -e ".${key} | if type==\"array\" then join(\"\") else . end"
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
    echo "${secret}"
}

function dispatch_functions () {
    declare -a myarray
    local i=0
    while IFS=$'\n' read -r line_data; do
        local array_entry="${line_data}"
        if (( i % 2 == 1 )); then
            case "$line_data" in
                acr_registry_key*)
                    array_entry="$(process_acr_registry_key "${line_data}")"
                    ;;
                secure_secret*)
                    array_entry="$(process_secure_secret "${line_data}")"
                    ;;
                *)
                   array_entry="UNDEFINED_FUNCTION [${line_data}]"
                   ;;
            esac
        fi
        myarray[i]="${array_entry}"
        ((++i))
    done

    i=0
    while (( ${#myarray[@]} > i )); do
        printf '%s' "${myarray[i++]}"
    done
}

function interpolate_functions () {
    awk '{gsub(/##/,"\n"); print}' | dispatch_functions
}

function prepare_k8s_string () {
    local attr="${1}"
    k8s_string "${attr}" '' | interpolate_functions
}

function option_if_true () {
    local -r option_config="${1}"
    local -r option_key="${2}"
    if [[ 'true' == "$(k8s_attr "${option_key}")" ]]; then
        printf -- "--%s" "${option_config}"
    fi
    true
}

function kubernetes_cluster_resource_group () {
    k8s_attr 'resource_group'
}

function fail_empty_set () {
    grep -q '^'
}

function kubernetes_cluster_already_exists () {
    $AZ_TRACE aks show \
        --name "$(kubernetes_cluster_name)" \
        --resource-group "$(kubernetes_cluster_resource_group)" \
        > /dev/stderr 2>&1
}

function create_kubernetes_cluster () {
    #shellcheck disable=SC2046
    $AZ_TRACE aks create \
        --name "$(kubernetes_cluster_name)" \
        --resource-group "$(kubernetes_cluster_resource_group)" \
        --location "$(k8s_attr 'location')" \
        --admin-username "$(k8s_attr 'admin_username')" \
        --attach-acr "$(k8s_attr 'attach_acr')" \
        --client-secret "$(prepare_k8s_string 'client_secret')" \
        $(option_if_true 'enable-cluster-autoscaler' 'enable_cluster_autoscaler') \
        $(option_if_true 'enable-managed-identity' 'enable_managed_identity') \
        $(option_if_true 'enable-private-cluster' 'enable_private_cluster') \
        $(option_if_true 'generate-ssh-keys' 'generate_ssh_keys') \
        --kubernetes-version "$(k8s_attr 'kubernetes_version')" \
        --load-balancer-sku "$(k8s_attr 'load_balancer_sku')" \
        --max-count "$(k8s_attr 'max_count')" \
        --max-pods "$(k8s_attr 'max_pods')" \
        --min-count "$(k8s_attr 'min_count')" \
        --network-plugin "$(k8s_attr 'network_plugin')" \
        --network-policy "$(k8s_attr 'network_policy')" \
        --node-count "$(k8s_attr 'node_count')" \
        --node-osdisk-size "$(k8s_attr 'node_osdisk_size')" \
        --node-vm-size "$(k8s_attr 'node_vm_size')" \
        --nodepool-labels $(k8s_attr 'nodepool_labels') \
        --nodepool-name "$(k8s_attr 'nodepool_name')" \
        --nodepool-tags $(k8s_attr 'nodepool_tags') \
        --service-principal "$(prepare_k8s_string 'service_principal')" \
        --ssh-key-value "$(k8s_attr 'ssh_key_value')" \
        --tags $(k8s_attr 'tags') \
        --vm-set-type "$(k8s_attr 'vm_set_type')" \
        --zones $(k8s_attr 'zones')

#        --api-server-authorized-ip-ranges "$(k8s_attr 'api_server_authorized_ip_ranges')"
#        --aad-tenant-id "$(k8s_attr 'aad_tenant_id')"
#        --aad-client-app-id "$(k8s_attr 'aad_client_app_id')"
#        --aad-server-app-id "$(k8s_attr 'aad_server_app_id')"
#        --aad-server-app-secret "$(k8s_attr 'aad_server_app_secret')"
}

function create_kubernetes_cluster_credentials () {
    $AZ_TRACE aks get-credentials \
        --name "$(kubernetes_cluster_name)" \
        --resource-group "$(kubernetes_cluster_resource_group)" \
        --overwrite-existing
}

function create_kubernetes_cluster_admin_credentials () {
    $AZ_TRACE aks get-credentials \
        --name "$(kubernetes_cluster_name)" \
        --resource-group "$(kubernetes_cluster_resource_group)" \
        --overwrite-existing \
        --admin
}

function kubernetes_dashboard_admin_service_account () {
    cat <<DASHBOARD_ADMIN_SERVICE_ACCOUNT_TEMPLATE
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
DASHBOARD_ADMIN_SERVICE_ACCOUNT_TEMPLATE
}

function kubernetes_dashboard_admin_cluster_role () {
    cat <<DASHBOARD_ADMIN_CLUSTER_ROLE_TEMPLATE
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
DASHBOARD_ADMIN_CLUSTER_ROLE_TEMPLATE
}

function create_kubernetes_dashboard_admin_service_account () {
    kubectl apply -f <(kubernetes_dashboard_admin_service_account)
    kubectl apply -f <(kubernetes_dashboard_admin_cluster_role)
}

function deploy_kubernetes_cluster () {
    create_kubernetes_cluster
    create_kubernetes_cluster_credentials
    create_kubernetes_cluster_admin_credentials
    create_kubernetes_dashboard_admin_service_account
}

function create_kubernetes_cluster_if_needed () {
    if ! kubernetes_cluster_already_exists; then
        deploy_kubernetes_cluster
    fi
}

create_kubernetes_cluster_if_needed
