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
declare -r PASSAGE_PARTNER="${PASSAGE_PARTNER:-Lighthouse}"
declare -r PASSAGE_ENVIRONMENT="${PASSAGE_ENVIRONMENT:-ASP_DEV_US}"
declare -r PASSAGE_ORGANIZATION="${PASSAGE_ORGANIZATION:-ABL Development System}"
declare -r ECLYPSE_ID="${ECLYPSE_ID:-ECYS1000-7D0D6DF9-1C66-5D73-8A9C-8F272A62AA64}"

function passages_base_url () {
    printf 'https://%s/api/v1' "${PASSAGE_HOST}"
}

function site_token () {
#    az account get-access-token --subscription 'Lighthouse-Dev' 2>/dev/null | jq -r '.accessToken'
#    az account get-access-token --subscription 'Allspice-Dev' 2>/dev/null | jq -r '.accessToken'
    echo 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IkJCOENlRlZxeWFHckdOdWVoSklpTDRkZmp6dyIsImtpZCI6IkJCOENlRlZxeWFHckdOdWVoSklpTDRkZmp6dyJ9.eyJhdWQiOiIyNGI3NjViNS04MTA4LTQzNzQtODE0MS0xYTY1YzBmYzQyYWIiLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC9jYWFkYmU5Ni0wMjRlLTRmNjctODJlYy1mYjI4ZmY1M2QxNmQvIiwiaWF0IjoxNTc1MzA5ODQwLCJuYmYiOjE1NzUzMDk4NDAsImV4cCI6MTU3NTMxMzc0MCwiYWNyIjoiMSIsImFpbyI6IkFTUUEyLzhOQUFBQXRNUG9xbkI0SzgybHMyeGpRWGM5SUlTU1YwWkx5blF0bGNyd2N2dHZ5dnM9IiwiYW1yIjpbInB3ZCJdLCJhcHBpZCI6IjNhNjA4NWQ5LTY3NmEtNDczYy04MzJmLWI3M2IyYjdmNzU2MSIsImFwcGlkYWNyIjoiMCIsImZhbWlseV9uYW1lIjoiQ2hhcmx0b24iLCJnaXZlbl9uYW1lIjoiUGF1bCIsImlwYWRkciI6IjExMC4xNjQuMTg4LjE0NiIsIm5hbWUiOiJDaGFybHRvbiwgUGF1bCAtIENUUiIsIm9pZCI6IjM2YmM3ZjZiLTIxNjEtNDE1Yy1hMDBlLTQzMzJiNTlhYWE5OSIsIm9ucHJlbV9zaWQiOiJTLTEtNS0yMS0yMDI1MTkzNTU4LTIwNzYxOTAyMjUtMTkzNDI1NTI2My0xODg5NjMiLCJzY3AiOiJ1c2VyX2ltcGVyc29uYXRpb24iLCJzdWIiOiJ6bm9jNWVWLTljV2hEMnFlWGg4OV9mNVhTclJrUHBOV0JlZ1lHNnlYOF9vIiwidGlkIjoiY2FhZGJlOTYtMDI0ZS00ZjY3LTgyZWMtZmIyOGZmNTNkMTZkIiwidW5pcXVlX25hbWUiOiJQWEMwOEBhY3VpdHlzc28uY29tIiwidXBuIjoiUFhDMDhAYWN1aXR5c3NvLmNvbSIsInV0aSI6Ii0wZUdkbVBNb0UtM19HWjlFdEV1QVEiLCJ2ZXIiOiIxLjAifQ.YEKFKHcA_9VkRy62tgSHF10-Zu_nQ2wQL04oUDAFjdPWFUAee-Vix8N465tHExnlDFEpm7T1wUO_BL-BIN1gadJYWtwzYlfqQ7WW8NkECRtYjlQ46_1zuNKFqZ_qrGvsWIE9eC2AAcEQnesapTUytWsiBdiowPTphNF7K68qa6TDg-knJQbICpzztLuAE2No0TfyDQaK4w2DjrPaQ8Df5ywLr2yG_o-aKfKW_ZXyKxKJO2wFn-xK5CAjjlWr8biLF5aIw7OEts6Y8z7adAiXkKNuSDldzvDR2gep05C2ENUhf75mhuq28KmhX38Tq8PcRIe0fur6qGCCtevBw_wfVw'
}

function get_device_id () {
    printf '%s' "${ECLYPSE_ID}"
}

function eclypse_partner_info () {
    local cmd
    cmd="curl -vv -sS -H 'Authorization: Bearer $(site_token)' -H 'Host: passage.atrius-dev.acuitynext.io' --referer 'https://passage.atrius-dev.acuitynext.io/swagger/ui/index' -X GET --header 'Accept: application/json' '$(passages_base_url)/partners/entities-and-environments'"
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
