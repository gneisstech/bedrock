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
  echo 'https://cf.dev.atrius-iot.com'
  #echo 'http://atgcfexp-post-auth-pip.southcentralus.cloudapp.azure.com'
}

function dev_backend_url () {
  echo 'https://atgcf-admin-api.azurewebsites.net'
}

function site_token () {
  az account get-access-token 2>/dev/null | jq -r '.accessToken'
}

function curl_auth () {
  local -r theURL="${1}"
  curl -sS -H "Authorization: Bearer $(site_token)" "${theURL}" --fail -w "%{http_code}:\n" 2>/dev/null || echo "Unauthorized"
}

function curl_x_auth_request_access_token () {
  local -r theURL="${1}"
  curl -sS -H "X-Auth-Request-Access-Token: $(site_token)" "${theURL}" --fail -w "%{http_code}:\n" -v || echo "Unauthorized"
}

function curl_x_forwarded_access_token () {
  local -r theURL="${1}"
  curl -sS -H "X-Forwarded-Access-Token: $(site_token)" "${theURL}" --fail -w "%{http_code}: \n" 2>/dev/null || echo "Unauthorized"
}

function check_admin_api_auth () {
  echo "=== begin checking admin_api URL of site"
  curl_auth "$(dev_site_url)/cf-admin/api/v1/orgs"
}

function check_admin_api_x_auth () {
  echo "=== begin checking admin_api URL of site with x-auth"
  curl_x_auth_request_access_token "$(dev_site_url)/cf-admin/api/v1/orgs"
}

function check_admin_api_x_forwarded () {
  echo "=== begin checking admin_api URL of site with x-forwarded"
  curl_x_forwarded_access_token "$(dev_site_url)/cf-admin/api/v1/orgs"
}

function check_admin_backend_api_auth () {
  echo "=== begin checking admin_backend_api URL of site"
  curl_auth "$(dev_backend_url)/cf-admin/api/v1/orgs"
}

function check_admin_backend_api_x_auth () {
  echo "=== begin checking admin_backend_api URL of site with x-auth"
  curl_x_auth_request_access_token "$(dev_backend_url)/cf-admin/api/v1/orgs"
}

function check_admin_backend_api_x_forwarded () {
  echo "=== begin checking admin_backend_api URL of site with x-forwarded"
  curl_x_forwarded_access_token "$(dev_backend_url)/cf-admin/api/v1/orgs"
}

function admin_api_check () {
  check_admin_api_auth
  check_admin_api_x_auth
  check_admin_api_x_forwarded
  check_admin_backend_api_auth
  check_admin_backend_api_x_auth
  check_admin_backend_api_x_forwarded
}

admin_api_check
