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
declare -r ECLYPSE_CONTEXT="${1}"

function repo_root () {
    git rev-parse --show-toplevel
}

function eclypse_handler () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.handler'
}

function invoke_eclypse_context () {
    local api_path="${1}"
    $(repo_root)/tests/$(eclypse_handler) "${ECLYPSE_CONTEXT}" "${api_path}"
}

function eclypse_firmware () {
    echo "=== begin retrieving eclypse_firmware"
    invoke_eclypse_context '/protocols/ips-luminaire/firmware' | jq
    echo "=== end retrieving eclypse_firmware"
}

function eclypse_atrius_setup () {
    echo "=== begin retrieving eclypse_atrius_setup"
    invoke_eclypse_context '/system/cloud/providers/atrius' | jq
    echo "=== end retrieving eclypse_atrius_setup"
}

function eclypse_backup_targets () {
    echo "=== begin retrieving eclypse_backup_targets"
    invoke_eclypse_context '/system/backup/targets' | jq
    echo "=== end retrieving eclypse_backup_targets"
}

function eclypse_files () {
    echo "=== begin retrieving eclypse_files"
    invoke_eclypse_context '/files/www' | jq
    echo "=== end retrieving eclypse_files"
}

function eclypse_check () {
    eclypse_firmware
    eclypse_atrius_setup
    eclypse_backup_targets
    eclypse_files
}

eclypse_check
