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
declare -r ECLYPSE_HOST='10.131.40.222'
#declare -r ECLYPSE_HOST='4.30.127.123:33443'
declare -r ECLYPSE_USER='admin'
declare -r ECLYPSE_PASSWORD='Acuity00'

function create_local_context () {
    cat <<LOCAL_CONTEXT
{
    "handler" : "eclypse_local_host_handler.sh",
    "values" : {
        "host" : "${ECLYPSE_HOST}",
        "user" : "${ECLYPSE_USER}",
        "password" : "${ECLYPSE_PASSWORD}"
    }
}
LOCAL_CONTEXT
}

function eclypse_local_check () {
    ./eclypse_check.sh "$(create_local_context)"
}

eclypse_local_check
