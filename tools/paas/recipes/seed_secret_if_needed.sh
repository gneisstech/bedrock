#!/usr/bin/env bash
# usage: seed_secret_if_needed.sh ResourceGroupName KeyVaultName

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

# Arguments
# ---------------------
declare -rx SECRET_NAME="${1}"

function repo_root () {
    git rev-parse --show-toplevel
}

function target_config () {
    printf '%s' "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function saas_configuration () {
    yq eval-all --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function secret_name () {
    printf '%s' "${SECRET_NAME}"
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function seed_secret_if_needed () {
#    secret_already_exists || seed_secret
    printf 'Seeding Secret [%s]\n' "$(secret_name)"
}

seed_secret_if_needed
