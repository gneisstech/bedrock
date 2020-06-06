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

function datadog_metric_payload () {
    local -r metric_name="${1}"
    local -r metric_value="${2}"
cat <<EOF
{
  "series": [
    {
      "metric": "cf.ci_cmd_duration.${metric_name}",
      "points": [ "${metric_value}" ]
    }
  ]
}
EOF
}

function report_metric_to_datadog () {
    if [[ -n "${DD_CLIENT_API_KEY:-}" ]] && [[ -n "${DD_CLIENT_APP_KEY:-}" ]]; then
        # Curl command
        curl -X POST "https://api.datadoghq.com/api/v1/series?api_key=${DD_CLIENT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d @<(datadog_metric_payload "$@") \
        || true
    fi
}

report_metric_to_datadog "$@"
