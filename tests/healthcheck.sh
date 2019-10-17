#!/usr/bin/env bash
# usage: docker_install.sh

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

function dev_site_url () {
  echo 'https://cf-qa01.dev.atrius-iot.com'
  #echo 'http://atgcfexp-post-auth-pip.southcentralus.cloudapp.azure.com'
}

function site_token () {
  az account get-access-token 2>/dev/null | jq -r '.accessToken'
}

function curl_auth () {
  local -r theURL="${1}"
  curl -sS -H "Authorization: Bearer $(site_token)" "${theURL}" --fail -w "%{http_code}: " -o /dev/null 2>/dev/null || echo "Unauthorized"
}

function check_main () {
  echo "=== begin checking root URL of site"
  curl -sS "$(dev_site_url)"
  echo
  echo "=== done checking root URL of site"
}

function check_auth_proxy () {
  echo "=== begin checking auth_proxy of site"
  curl -sS "$(dev_site_url)/robots.txt"
  echo
  echo "=== done checking auth_proxy of site"
}

function check_app () {
  echo "=== begin checking app URL of site"
  curl_auth "$(dev_site_url)/cf-app/"
  echo "=== done checking app URL of site"
}

function check_admin_api () {
  echo "=== begin checking admin_api URL of site"
  curl_auth "$(dev_site_url)/cf-admin"
  echo "=== begin checking admin_api URL of site"
}

function check_ingest_api () {
  echo "=== begin checking ingest_api URL of site"
  curl_auth "$(dev_site_url)/cf-ingest"
  echo "=== begin checking ingest_api URL of site"
}

function check_health_api () {
  echo "=== begin checking health_api URL of site"
  curl_auth "$(dev_site_url)/cf-health"
  echo
  echo "=== begin checking health_api URL of site"
}

function check_self_healing_app () {
  echo "=== begin checking self_healing_app URL of site"
  curl_auth "$(dev_site_url)/cf-self-healing/"
  echo "=== begin checking self_healing_app URL of site"
}

function check_self_healing_api () {
  echo "=== begin checking self_healing_api URL of site"
  curl_auth "$(dev_site_url)/cf-self-healing-api"
  echo "=== begin checking self_healing_api URL of site"
}

function healthcheck () {
  check_main
  check_auth_proxy
  check_app
  check_admin_api
  check_ingest_api
  check_health_api
  check_self_healing_app
  check_self_healing_api
}

healthcheck
