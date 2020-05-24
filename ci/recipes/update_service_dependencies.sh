#!/usr/bin/env bash
# usage: update_service_dependencies.sh

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx BUILD_SOURCEBRANCH
declare -rx BUILD_SOURCEBRANCHNAME
declare -rx TF_BUILD

# Arguments
# ---------------------

declare -rx ORIGIN_ENVIRONMENT="${ORIGIN_ENVIRONMENT:-dev}"
declare -rx ORIGIN_REPOSITORY="${ORIGIN_REPOSITORY:-cfdevregistry}"
declare -rx RELEASE_PREFIX="${RELEASE_PREFIX:-r}"
declare -rx BUILD_REPOSITORY_LOCALPATH="${BUILD_REPOSITORY_LOCALPATH:-.}"

function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function git_repo_branch () {
    git rev-parse --abbrev-ref HEAD
}

function current_repo_branch () {
    local branch
    if is_azure_pipeline_build; then
        branch="${BUILD_SOURCEBRANCHNAME:-}"
    else
        branch="$(git_repo_branch)"
    fi
    printf "%s" "${branch}"
}

function trace_environment () {
    printf 'triggered build from [%s]' "${BUILD_SOURCEBRANCH:-}\n"
    git status
    printf 'branches: current [%s], build_sourcebranch [%s], git branch [%s]\n' \
        "$(current_repo_branch)" \
        "${BUILD_SOURCEBRANCH:-}" \
        "$(git_repo_branch)"
    env
}

function install_yq_if_needed () {
    if ! command -v yq; then
        sudo add-apt-repository ppa:rmescandon/yq > /dev/null 2>&1
        sudo apt update > /dev/null 2>&1
        sudo apt install yq -y > /dev/null 2>&1
    fi
}

#
# there are four basic cases to consider:
# chart.lock semver matches latest service semver => no change
# chart.lock semver does not match latest service semver => remove lock, rebuild umbrella [inspect service semver for new feature or breaking change, respond accordingly]
# chart.lock semver does not exist for service => remove lock, rebuild umbrella [ new feature change ]
# chart.lock semver exists, but no artifacts for service => remove lock, rebuild umbrella [breaking change]
#

function get_upstream_services () {
    env | grep 'PIPELINENAME' | sed -e 's|.*=||' | sort -u
}

function chart_dir () {
    printf '%s/configuration/k8s/charts/cf-deployment-umbrella/' "$(repo_root)"
}

function filter_upstream_cf_services () {
    jq -r -e \
        --arg repository "${ORIGIN_REPOSITORY}" \
        '.dependencies[] | select(.repository|test(".*\($repository).*")) | .name' \
      | sort -u
}

function get_chart_services () {
    yq r --tojson "$(chart_dir)/Chart.yaml" | filter_upstream_cf_services || true
}

function get_locked_chart_services () {
    yq r --tojson "$(chart_dir)/Chart.lock" | filter_upstream_cf_services || true
}

function get_helm_services_json () {
    az acr helm repo add -n "${ORIGIN_REPOSITORY}"
    helm repo update
    helm search repo "${ORIGIN_REPOSITORY}" --devel -o json
}

function get_helm_services () {
    tee /dev/stdderr | jq -r '.[].name' | sed -e 's|.*/||' -e 's|"$||' | sort -u
}

function services_changed_semver () {
set -x
    local upstream_services chart_services locked_chart_services helm_services_json helm_services
    upstream_services="$(get_upstream_services)"
    chart_services="$(get_chart_services)"
    locked_chart_services="$(get_locked_chart_services)"
    helm_services_json="$(get_helm_services_json)"
    helm_services="$(get_helm_services <<< "${helm_services_json}")"
    printf 'upstream [%s]\n\n' "${upstream_services}"
    printf 'chart [%s]\n\n' "${chart_services}"
    printf 'locked chart [%s]\n\n' "${locked_chart_services}"
    printf 'helm [%s]\n\n' "${helm_services}"
}

function update_service_dependencies () {
    trace_environment
    install_yq_if_needed
    if services_changed_semver; then
        # shellcheck disable=2046
        $(repo_root)/ci/recipes/update_umbrella_chart.sh
    fi
}

update_service_dependencies
