#!/usr/bin/env bash
# usage: eclypse_relay_api_handler.sh CONTEXT API_PATH

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

function passage_host () {
    # passage.atrius-dev.acuitynext.io
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.passage_host'
}

function passage_atr_entity_key () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.atr_entity_key'
}

function eclypse_device_id () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.eclypse_device_id'
}

function site_token () {
    printf '%s' "${ECLYPSE_CONTEXT}" | jq -r -e '.values.site_token'
}

function passage_relay_url () {
    printf 'https://%s/api/v1/Devices/%s/request' "$(passage_host)" "$(eclypse_device_id)"
}

function eclypse_curl () {
    local cmd
    cmd="curl -vv -sS -H 'Authorization: Bearer $(site_token)' -H 'atr-entity-key: $(passage_atr_entity_key)' -H 'Host: passage.atrius-dev.acuitynext.io' --referer 'https://passage.atrius-dev.acuitynext.io/swagger/ui/index' -X GET --header 'Accept: application/json' --header 'Eclypse-Rest-Api: ${API_PATH}' '$(passage_relay_url)'"
    printf "%s" "${cmd}" 2> /dev/null > /dev/stderr
    eval "${cmd}" 2> /dev/null
}

function eclypse_local_host_handler () {
    eclypse_curl
}

eclypse_local_host_handler
