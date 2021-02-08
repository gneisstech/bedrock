#!/usr/bin/env bash
# usage: report_metric_to_datadog.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx DD_SECRET_VAULT

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function get_app() {
  printf 'cf'
}

function get_env() {
  printf 'ci'
}

function metric_context () {
    printf '%s.%s_cmd_duration' "$(get_app)" "$(get_env)"
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
        2> /dev/null \
    | jq -r '.value'
}

function get_dd_client_api_key () {
  get_vault_secret "${DD_SECRET_VAULT}" 'datadog-api-key'
}

function get_dd_client_app_key () {
  get_vault_secret "${DD_SECRET_VAULT}" 'datadog-app-key'
}

function datadog_metric_definition () {
    local -r metric_name="${1}"
cat <<EOF
{
  "description": "Duration of CI Script Run for [${metric_name}] in seconds",
  "per_unit": "command",
  "short_name": "${metric_name}",
  "type": "gauge",
  "unit": "second"
}
EOF
}

function define_datadog_metric_metadata () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
    local -r dd_url="https://api.datadoghq.com/api/v1/metrics/$(metric_context).${metric_name}"

    printf 'Defining metric: [%s]\n  to: %s\n' "$(datadog_metric_definition "${metric_name}" )" "${dd_url}"
    # Curl command
    curl -X PUT "${dd_url}" \
        -H "Content-Type: application/json" \
        -H "DD-API-KEY: $(get_dd_client_api_key)" \
        -H "DD-APPLICATION-KEY: $(get_dd_client_app_key)" \
        -d @<(datadog_metric_definition "${metric_name}")
}

function datadog_metric_payload () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
cat <<EOF
{
  "series": [
    {
      "host": "$(app)$(env)_full_test",
      "metric": "$(metric_context).${metric_name}",
      "points": [ [ "$(date +%s)", "${metric_value}"] ],
      "tags": [ "env:$(get_app)$(get_env)" ],
      "type": "gauge"
    }
  ]
}
EOF
}

function send_datadog_metric () {
        local -r dd_url="https://api.datadoghq.com/api/v1/series"
        printf 'Sending metric: [%s]\n  to: %s\n' "$(datadog_metric_payload "$@")" "${dd_url}"
        # Curl command
        curl -X POST "${dd_url}?api_key=$(get_dd_client_api_key)" \
            -H "Content-Type: application/json" \
            -d @<(datadog_metric_payload "$@")
}

function report_metric_to_datadog () {
    if [[ -n "$(get_dd_client_api_key)" ]] && [[ -n "$(get_dd_client_app_key)" ]]; then
        send_datadog_metric "$@" > /dev/null 2>&1 || true
        define_datadog_metric_metadata "$@" > /dev/null 2>& 1|| true
    fi
}

report_metric_to_datadog "$@"
