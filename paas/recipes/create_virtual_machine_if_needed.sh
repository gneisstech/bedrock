#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_virtual_machine_if_needed.sh vm_name

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
declare -rx VIRTUAL_MACHINE_NAME="${1}"

function virtual_machine_name () {
    echo "${VIRTUAL_MACHINE_NAME}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function target_config () {
    printf '%s/%s' "$(repo_root)" "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function server_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".virtual_machines[] | select(.name == \"$(virtual_machine_name)\") | .${attr}"
}

function virtual_machine_resource_group () {
    server_attr 'resource_group'
}

function virtual_machine_admin_name () {
    server_attr 'admin_name'
}

function fetch_kv_virtual_machine_admin_password () {
    az keyvault secret show \
        --vault-name "$(server_attr 'admin_password_kv.vault')" \
        --name "$(server_attr 'admin_password_kv.secret_name')" \
        2> /dev/null \
    | jq -r '.value'
}

function random_key () {
    hexdump -n 27 -e '27/1 "%02.2X"' /dev/urandom
}

function create_kv_virtual_machine_admin_password () {
    local password
    password="pass_$(random_key)"
    az keyvault secret set \
        --vault-name "$(server_attr 'admin_password_kv.vault')" \
        --name "$(server_attr 'admin_password_kv.secret_name')" \
        --description "admin password for virtual machine [$(virtual_machine_name)]" \
        --value "${password}" \
    | jq -r '.value'
}

function virtual_machine_admin_password () {
    local password
    password=$(fetch_kv_virtual_machine_admin_password)
    if [[ -z "${password:-}" ]]; then
        password=$(create_kv_virtual_machine_admin_password)
        if [[ -z "${password:-}" ]]; then
            return 1
        fi
    fi
    echo -n "${password}"
}

function virtual_machine_already_exists () {
    az vm show \
        --name "$(virtual_machine_name)" \
        --resource-group "$(virtual_machine_resource_group)" \
        > /dev/null 2>&1
}

function data_disk_sizes_gb () {
    paas_configuration | jq -r -e '.virtual_machines[0].disks.data_disks.data_disk_sizes_gb | @tsv'
}

function deploy_virtual_machine () {
    $AZ_TRACE vm create \
        --name "$(virtual_machine_name)" \
        --resource-group "$(virtual_machine_resource_group)" \
        --assign-identity \
        --admin-user "$(virtual_machine_admin_name)" \
        --admin-password "$(virtual_machine_admin_password)" \
        --license-type "$(server_attr 'license_type')" \
        --public-ip-address "$(server_attr 'public_ip_address')" \
        --os-disk-caching "$(server_attr 'disks.os_disk.os_disk_caching')" \
        --os-disk-name "$(server_attr 'disks.os_disk.os_disk_name')" \
        --os-disk-size-gb "$(server_attr 'disks.os_disk.os_disk_size_gb')" \
        --location "$(server_attr 'location')" \
        --image "$(server_attr 'image')" \
        --size "$(server_attr 'size')" \
        --priority "$(server_attr 'priority')" \
        --authentication-type  "$(server_attr 'authentication_type')" \
        --vnet-name "$(server_attr 'vnet_name')" \
        --subnet "$(server_attr 'subnet_name')" \
        --data-disk-caching "$(server_attr 'disks.data_disks.data_disk_caching')" \
        --data-disk-sizes-gb "$(data_disk_sizes_gb)" \


cat >/dev/null <<EOF
#        --boot-diagnostics-storage "$(server_attr 'boot_diagnostics_storage')"

             [--nsg]
             [--nsg-rule {RDP, SSH}]
             [--plan-name]
             [--plan-product]
             [--plan-promotion-code]
             [--plan-publisher]
             [--ppg]
             [--role]
             [--scope]
             [--secrets]
             [--ssh-dest-key-path]
             [--ssh-key-values]
             [--storage-account]
             [--storage-container-name]
             [--storage-sku]
             [--subnet]
             [--subnet-address-prefix]
             [--tags]
             [--ultra-ssd-enabled {false, true}]
             [--use-unmanaged-disk]
             [--validate]
             [--vmss]
             [--vnet-address-prefix]
             [--workspace]
EOF
}

function create_virtual_machine_if_needed () {
    virtual_machine_already_exists || deploy_virtual_machine
}

create_virtual_machine_if_needed
