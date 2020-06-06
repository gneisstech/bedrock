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
        curl -L https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -o yq-local
        chmod +x yq-local
        sudo mv yq-local /usr/bin/yq
#        sudo add-apt-repository ppa:rmescandon/yq
#        sudo apt update -y
#        sudo apt install yq -y
    fi
}

function install_jq_if_needed () {
set -x
    curl -L -o jq-local https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod +x jq-local
    sudo mv jq-local /usr/bin/jq
set +x
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

install_tools_if_needed 2> >(while read -r line; do (echo "STDERR: $line"); done)
