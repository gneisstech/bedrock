#!/usr/bin/env bash
# usage: bless_development_artifacts.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"
declare -rx IMAGENAME="${IMAGENAME:-cf-ecy-ingest-svc-docker}"

# Arguments
# ---------------------


function repo_root () {
    git rev-parse --show-toplevel
}

function blackduck_scanner () {
  local -r licenseKeyPath="${1}"
  local -r imageName="${2}"
  local -r tag="${3}"
  local -r max_allowed_cve_high="${4}"
  local -r max_allowed_cve_medium="${5}"

  pushd "${BUILD_REPOSITORY_LOCALPATH}"
  pwd
    docker run \
      --name neuvector.scanner \
      --rm \
      -e SCANNER_REPOSITORY="cfdevregistry.azurecr.io/${imageName}" \
      -e SCANNER_TAG="${tag}" \
      -e SCANNER_LICENSE="$(cat "${licenseKeyPath}")" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$(pwd)":/var/neuvector \
      'cfdevregistry.azurecr.io/neuvector/scanner:latest'
    printf "======== High priority CVE ========\n"
    show_cve_high 'scan_result.json'
    printf "======== Medium priority CVE ========\n"
    show_cve_medium 'scan_result.json'
    fail_cve_high 'scan_result.json' "${max_allowed_cve_high}"
    fail_cve_medium 'scan_result.json' "${max_allowed_cve_medium}"
    printf "======== CVE checks passed --------\n"
  popd
}

blackduck_scanner "$@" || true
