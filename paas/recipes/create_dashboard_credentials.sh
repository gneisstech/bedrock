#!/usr/bin/env bash
# usage: create_dashboard_credentials.sh

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

function create_dashboard_credentials () {
    create_kubernetes_dashboard_admin_service_account
}

create_dashboard_credentials
