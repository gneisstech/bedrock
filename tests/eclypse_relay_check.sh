#!/usr/bin/env bash
# usage: eclypse_relay_check.sh

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
declare -r PASSAGE_HOST="${PASSAGE_HOST:-passage.atrius-dev.acuitynext.io}"
declare -r PASSAGE_API="${PASSAGE_API:-24b765b5-8108-4374-8141-1a65c0fc42ab}"
declare -r PASSAGE_PARTNER="${PASSAGE_PARTNER:-Lighthouse}"
declare -r PASSAGE_ENVIRONMENT="${PASSAGE_ENVIRONMENT:-ASP_DEV_US}"
declare -r PASSAGE_ORGANIZATION="${PASSAGE_ORGANIZATION:-ABL Development System}"
#declare -r ECLYPSE_ID="${ECLYPSE_ID:-ECYS1000-7D0D6DF9-1C66-5D73-8A9C-8F272A62AA64}"
declare -r ECLYPSE_ID="${ECLYPSE_ID:-ECYS1000-D504C5B9-A911-5B36-A41D-19B2FB088EC8}"

function passages_base_url () {
    printf 'https://%s/api/v1' "${PASSAGE_HOST}"
}

function site_token () {
    az account get-access-token --subscription 'Allspice-Dev' --resource "${PASSAGE_API}" 2>/dev/null | jq -r '.accessToken'
}

function get_device_id () {
    printf '%s' "${ECLYPSE_ID}"
}

function eclypse_partner_info () {
    local cmd
    cmd="curl -vv -sS"
    cmd+=" --header 'Authorization: Bearer $(site_token)'"
    cmd+=" --header 'Host: passage.atrius-dev.acuitynext.io'"
    cmd+=" --referer 'https://passage.atrius-dev.acuitynext.io/swagger/ui/index'"
    cmd+=" -X GET"
    cmd+=" --header 'Accept: application/json'"
    cmd+=" '$(passages_base_url)/partners/entities-and-environments'"
    printf "%s" "${cmd}" > /dev/null
    eval "${cmd}" 2> /dev/null
}

function eclypse_partner_key () {
    eclypse_partner_info | jq -r -e ".result | .[] | select (.partnerName == \"${PASSAGE_PARTNER}\") | .environments[] | select(.environmentName == \"${PASSAGE_ENVIRONMENT}\") | .entityKey"
}

function get_atrius_organizations () {
    local cmd
    cmd="curl -vv -sS -H 'Authorization: Bearer $(site_token)' -H 'atr-entity-key: $(eclypse_partner_key)' -H 'Host: passage.atrius-dev.acuitynext.io' --referer 'https://passage.atrius-dev.acuitynext.io/swagger/ui/index' -X GET --header 'Accept: application/json' '$(passages_base_url)/organizations?active=active'"
    printf "%s" "${cmd}" > /dev/null
    eval "${cmd}" 2> /dev/null
}

function get_atrius_organization_key () {
    get_atrius_organizations | jq -r -e ".result[] | select (.organizationName == \"${PASSAGE_ORGANIZATION}\") | .entityKey"
}

function create_local_context () {
    cat <<LOCAL_CONTEXT
{
    "handler" : "eclypse_relay_api_handler.sh",
    "values" : {
        "passage_host" : "${PASSAGE_HOST}",
        "eclypse_device_id" : "$(get_device_id)",
        "atr_entity_key" : "$(get_atrius_organization_key)",
        "site_token" : "$(site_token)"
    }
}
LOCAL_CONTEXT
}


function eclypse_relay_check () {
    ./eclypse_check.sh "$(create_local_context)"
}

eclypse_relay_check
