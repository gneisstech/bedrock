#!/usr/bin/env bash
# usage: install_tools_if_needed.sh

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

function install_yq_if_needed () {
    if ! command -v yq; then
        sudo add-apt-repository ppa:rmescandon/yq
        sudo apt update -y
        sudo apt install yq -y
    fi
}

function install_jq_if_needed () {
    if ! command -v jq; then
        local -r required_minimum='jq-1.6'
        local test_version
        test_version="$(sort <(echo "${required_minimum}") <(jq -V) -u | head -1)"
        if (( test_version != required_minimum )); then
            sudo apt-get update -y
            sudo apt-get install -y jq
        fi
    fi
}

function install_shellcheck_if_needed () {
    if ! command -v shellcheck; then
        printf 'Shellcheck is needed ...\n'
    fi
}

function install_yamllint_if_needed () {
    if ! command -v yamllint; then
        printf 'yamllint is needed ...\n'
    fi
}

function install_tools_if_needed () {
    install_yq_if_needed
    install_jq_if_needed
    install_shellcheck_if_needed
    install_yamllint_if_needed
}

install_tools_if_needed
