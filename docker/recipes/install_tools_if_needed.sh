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
declare -rx K8S_RELEASE="${K8S_RELEASE:-v1.20.2}"
declare -rx YQ_RELEASE="${YQ_RELEASE:-2.4.0}"
declare -rx JQ_RELEASE="${JQ_RELEASE:-jq-1.6}"

# Arguments
# ---------------------

function install_docker() {
  apk add docker
}

function install_python3() {
  apk add python3 py3-pip
}

function install_az_cli() {
  apk update
  apk add bash py3-pip
  apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python3-dev make
  pip --no-cache-dir install -U pip
  pip --no-cache-dir install azure-cli
  apk del --purge build
  az extension add --upgrade --name azure-devops
  az version
}

function install_kubectl() {
  curl -LSo '/usr/local/bin/kubectl' "https://storage.googleapis.com/kubernetes-release/release/${K8S_RELEASE}/bin/linux/amd64/kubectl"
  chmod +x '/usr/local/bin/kubectl'
}

function install_helm() {
  apk add openssl
  curl -fsSL -o 'get_helm.sh' 'https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3'
  chmod 700 'get_helm.sh'
  ./get_helm.sh
}

function install_git() {
  apk add git
}

function install_make() {
  apk add make
}

function install_curl() {
  apk add curl
}

function install_netcat() {
  apk add netcat-openbsd
}

function install_yq_if_needed() {
  if ! command -v yq; then
    curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_RELEASE}/yq_linux_amd64" -o yq-local
    chmod +x 'yq-local'
    mv 'yq-local' '/usr/bin/yq'
  fi
}

function install_jq_if_needed() {
  curl -L -o 'jq-local' "https://github.com/stedolan/jq/releases/download/${JQ_RELEASE}/jq-linux64"
  chmod +x 'jq-local'
  mv 'jq-local' '/usr/bin/jq'
}

function install_shellcheck_if_needed() {
  if ! command -v shellcheck; then
    printf 'Shellcheck is needed ...\n'
    apk add shellcheck
  fi
}

function install_yamllint_if_needed() {
  if ! command -v yamllint; then
    printf 'yamllint is needed ...\n'
    apk add yamllint
  fi
}

function install_tools_if_needed() {
  set -x
  SECONDS=0
  install_curl
  install_python3
  install_az_cli
  install_docker
  install_kubectl
  install_helm
  install_git
  install_make
  install_netcat
  install_yq_if_needed
  install_jq_if_needed
  install_shellcheck_if_needed
  install_yamllint_if_needed
  #    install_aws_cli
  #    install_gcp_cli
  DD_CLIENT_API_KEY="${1:-}" DD_CLIENT_APP_KEY="${2:-}" "/recipes/report_metric_to_datadog.sh" "${FUNCNAME[0]}" "${SECONDS}"
}

install_tools_if_needed "$@" 2> >(while read -r line; do (echo "LOGGING: $line"); done)
