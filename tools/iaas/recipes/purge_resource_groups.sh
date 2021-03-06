#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml purge_resource_groups.sh

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
declare -rx AZ_TRACE="${AZ_TRACE:-echo az}"

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function target_config () {
    printf '%s' "${TARGET_CONFIG}"
}

function iaas_configuration () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.iaas'
}

function resource_group_names () {
    iaas_configuration | jq -r -e '[.resource_groups[]? | select(.action == "create") | .name ] | @tsv'
}

function purge_resource_groups () {
    # shellcheck disable=2086
    resource_group_names | xargs -n 1 -P 10 -r $AZ_TRACE group delete --yes --name
}

# retry a second time to remove cyclic dependencies in the resource group graph
purge_resource_groups || purge_resource_groups || true
