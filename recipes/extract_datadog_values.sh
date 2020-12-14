#!/usr/bin/env bash
# usage: extract_datadog_values.sh "{deployment_json}"

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

function read_raw_configuration () {
    local -r deployment_json="${1}"
    "$(repo_root)/recipes/read_raw_configuration.sh" "${deployment_json}"
}

function get_app () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.app' <<< "${deployment_json}"
}

function get_env () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.name' <<< "${deployment_json}"
}

function extract_datadog_values () {
    local -r deployment_json="${1}"
    local app env
    app="$(get_app "${deployment_json}")"
    env="$(get_env "${deployment_json}")"
    read_raw_configuration "${deployment_json}" \
      | jq -r -e '.target.paas.k8s.datadog' \
      | "$(repo_root)/recipes/join_string_arrays.sh" \
      | "$(repo_root)/recipes/interpolate_strings.sh" "${app}" "${env}"
}

extract_datadog_values "${@}"
