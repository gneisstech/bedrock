#!/usr/bin/env bash
# usage: docker_install.sh

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
declare -rx ECLYPSE_HOST='10.131.40.222'
declare -rx ECLYPSE_USER='admin'
declare -rx ECLYPSE_PASSWORD='Acuity00'

function eclypse_rest_url () {
    printf 'https://%s/api/rest/v1' "${ECLYPSE_HOST}"
}

function eclypse_user_credentials () {
    printf '%s:%s' "${ECLYPSE_USER}" "${ECLYPSE_PASSWORD}"
}

function eclypse_curl () {
    local -r api_path="${1}"
    local cmd
    cmd="$(printf 'curl -sS -k --user "%s" --fail -H "Connection: close" %s%s' "$(eclypse_user_credentials)" "$(eclypse_rest_url)" "${api_path}")"
    echo evaluating "${cmd}" > /dev/stderr
    eval "${cmd}"
}

function eclypse_firmware () {
    echo "=== begin retrieving eclypse_firmware"
    eclypse_curl '/protocols/ips-luminaire/firmware' | jq
    echo "=== end retrieving eclypse_firmware"
}

function eclypse_atrius_setup () {
    echo "=== begin retrieving eclypse_atrius_setup"
    eclypse_curl '/system/cloud/providers/atrius' | jq
    echo "=== end retrieving eclypse_atrius_setup"
}

function eclypse_backup_targets () {
    echo "=== begin retrieving eclypse_backup_targets"
    eclypse_curl '/system/backup/targets' | jq
    echo "=== end retrieving eclypse_backup_targets"
}

function eclypse_files () {
    echo "=== begin retrieving eclypse_files"
    eclypse_curl '/files' | jq
    echo "=== end retrieving eclypse_files"
}

function eclypse_check () {
    eclypse_firmware
    eclypse_atrius_setup
    eclypse_backup_targets
    eclypse_files
}

eclypse_check
