#!/usr/bin/env bash
# usage: eclypse_local_check.sh

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
declare -r ECLYPSE_CONTEXT="${1}"
declare -r API_PATH="${2}"

function eclypse_host () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.host'
}

function eclypse_user () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.user'
}

function eclypse_password () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.password'
}

function eclypse_rest_url () {
    printf 'https://%s/api/rest/v1' "$(eclypse_host)"
}

function eclypse_user_credentials () {
    printf '%s:%s' "$(eclypse_user)" "$(eclypse_password)"
}

function eclypse_curl () {
    local cmd
    cmd="$(printf 'curl -sS -k --user "%s" --fail -H "Connection: close" %s%s' "$(eclypse_user_credentials)" "$(eclypse_rest_url)" "${API_PATH}")"
    echo evaluating "${cmd}" > /dev/stderr
    eval "${cmd}"
}

function eclypse_local_host_handler () {
    eclypse_curl
}

eclypse_local_host_handler
