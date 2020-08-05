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
declare -r PASSAGE_HOST="${PASSAGE_HOST:-passage.atrius-us.acuitynext.io}"
declare -r PASSAGE_API="${PASSAGE_API:-d9253624-7e87-426c-8132-75858e1dcf0b}"
declare -r PASSAGE_PARTNER="${PASSAGE_PARTNER:-Walgreens}"
declare -r PASSAGE_ENVIRONMENT="${PASSAGE_ENVIRONMENT:-Atrius Demo US}"
declare -r PASSAGE_ORGANIZATION="${PASSAGE_ORGANIZATION:-Walgreens}"
declare -r ECLYPSE_ID="${ECLYPSE_ID:-ECYS1000-FF3CCA25-84E7-571E-99FC-BC8AAE6668FD}"
declare -r PASSAGE_TENANT_ID="${PASSAGE_TENANT_ID:-caadbe96-024e-4f67-82ec-fb28ff53d16d}"

function repo_root () {
    git rev-parse --show-toplevel
}

function passages_base_url () {
    printf 'https://%s/api/v1' "${PASSAGE_HOST}"
}

function site_login () {
    az login \
        --service-principal \
        --password '[yPR7EsMtY]i[ci2.fGdaGOSdGyAD6W7' \
        --username '453111ae-5c35-4369-9807-2aff96da2def' \
        --tenant "${PASSAGE_TENANT_ID}" \
        --allow-no-subscriptions
}

function site_token () {
    site_login > /dev/null 2>&1
    az account get-access-token --resource "${PASSAGE_API}" --tenant "${PASSAGE_TENANT_ID}" 2>/dev/null | jq -r '.accessToken'
}

function get_device_id () {
    printf '%s' "${ECLYPSE_ID}"
}

function eclypse_partner_info () {
    local cmd
    cmd="curl -vv -sS"
    cmd+=" --header 'Authorization: Bearer $(site_token)'"
    cmd+=" --header 'Host: ${PASSAGE_HOST}'"
    cmd+=" --referer 'https://cf.us.atrius-iot.com/'"
    cmd+=" -X GET"
    cmd+=" --header 'Accept: application/json'"
    cmd+=" '$(passages_base_url)/partners/entities-and-environments'"
    printf "%s" "${cmd}" > /dev/null
    eval "${cmd}" 2> /dev/null
}

function eclypse_partner_key () {
    eclypse_partner_info | tee /dev/stderr | jq -r -e ".result | .[] | select (.partnerName == \"${PASSAGE_PARTNER}\") | .environments[] | select(.environmentName == \"${PASSAGE_ENVIRONMENT}\") | .entityKey"
}

function get_atrius_organizations () {
    local cmd
    cmd="curl -vv -sS"
    cmd+=" --header 'Authorization: Bearer $(site_token)'"
    cmd+=" --header 'atr-entity-key: $(eclypse_partner_key)'"
    cmd+=" --header 'Host: ${PASSAGE_HOST}'"
    cmd+=" --referer 'https://cf.us.atrius-iot.com/'"
    cmd+=" -X GET"
    cmd+=" --header 'Accept: application/json'"
    cmd+=" '$(passages_base_url)/organizations?active=active'"
    printf "%s" "${cmd}" > /dev/null
    eval "${cmd}" 2> /dev/null
}

function get_atrius_organization_key () {
    get_atrius_organizations | tee /dev/stderr | jq -r -e ".result[] | select (.organizationName == \"${PASSAGE_ORGANIZATION}\") | .entityKey"
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


function triage_wag_eclypse_relay_check () {
    #shellcheck disable=SC2046
    $(repo_root)/tests/eclypse_check.sh "$(create_local_context)"
}

#site_token
triage_wag_eclypse_relay_check
