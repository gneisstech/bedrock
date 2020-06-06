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

# Arguments
# ---------------------

function repo_root () {
    git rev-parse --show-toplevel
}

function metric_context () {
    printf 'cf.ci_cmd_duration'
}

function datadog_metric_definition () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
cat <<EOF
{
  "description": "Duration of CI Script Run in seconds",
  "per_unit": "run",
  "short_name": "${metric_name}",
  "type": "gauge",
  "unit": "seconds"
}
EOF
}

function define_datadog_metric_metadata () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
    printf 'Defining metric: [%s]\n' "$(datadog_metric_definition "$@")"
    # Curl command
    curl -X PUT "https://api.datadoghq.com/api/v1/metrics/$(metric_context).${metric_name}" \
        -H "Content-Type: application/json" \
        -H "DD-API-KEY: ${DD_CLIENT_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_CLIENT_APP_KEY}" \
        -d @<(datadog_metric_definition "$@")
}

function datadog_metric_payload () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
cat <<EOF
{
  "series": [
    {
      "metric": "$(metric_context).${metric_name}",
      "points": [ "${metric_value}" ]
    }
  ]
}
EOF
}

function send_datadog_metric () {
        printf 'Sending metric: [%s]\n' "$(datadog_metric_payload "$@")"
        # Curl command
        curl -X POST "https://api.datadoghq.com/api/v1/series?api_key=${DD_CLIENT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d @<(datadog_metric_payload "$@")
}

function report_metric_to_datadog () {
    if [[ -n "${DD_CLIENT_API_KEY:-}" ]] && [[ -n "${DD_CLIENT_APP_KEY:-}" ]]; then
        send_datadog_metric "$@" || true
        define_datadog_metric_metadata "$@" || true
    fi
}

report_metric_to_datadog "$@"
