#!/usr/bin/env bash
# usage: create_database_instance_if_needed.sh database_instance_name

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
declare -rx DATABASE_INSTANCE_NAME="${1}"

function database_instance_name (){
    echo "${DATABASE_INSTANCE_NAME}"
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

function db_attr () {
    local -r attr="${1}"
    paas_configuration | jq -r -e ".databases.instances[] | select(.name == \"$(database_instance_name)\") | .${attr}"
}

function database_instance_resource_group () {
    db_attr "resource_group"
}

function database_instance_server () {
    db_attr "server"
}

function database_instance_already_exists () {
    az sql db show \
        --name "$(database_instance_name)" \
        --resource-group "$(database_instance_resource_group)" \
        --server "$(database_instance_server)" \
        > /dev/null 2>&1
}

function deploy_database_instance () {
    $AZ_TRACE sql db create \
        --name "$(database_instance_name)" \
        --resource-group "$(database_instance_resource_group)" \
        --server "$(database_instance_server)" \
        --license-type "$(db_attr 'license_type')" \
        --max-size "$(db_attr 'max_size')" \
        --zone-redundant "$(db_attr 'zone_redundant')" \
        --catalog-collation "$(db_attr 'catalog_collation')" \
        --collation "$(db_attr 'collation')" \
        --capacity "$(db_attr 'capacity')" \
        --tier "$(db_attr 'tier')" \
        --family "$(db_attr 'family')" \
        --service-objective "$(db_attr 'service_objective')"
}

function create_database_instance_if_needed () {
    database_instance_already_exists || deploy_database_instance
}

create_database_instance_if_needed
