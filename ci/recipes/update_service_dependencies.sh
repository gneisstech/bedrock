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

#
# there are four basic cases to consider:
# chart.lock semver matches latest service semver => no change
# chart.lock semver does not match latest service semver => remove lock, rebuild umbrella [inspect service semver for new feature or breaking change, respond accordingly]
# chart.lock semver does not exist for service => remove lock, rebuild umbrella [ new feature change ]
# chart.lock semver exists, but no artifacts for service => remove lock, rebuild umbrella [breaking change]
#

function get_upstream_services () {
    env \
        | grep PIPELINENAME \
        | sed -e 's|_PIPELINENAME.*||' -e 's|.*_||' \
        | tr '[:upper:]' '[:lower:]' \
        | sort -u
}

function pipeline_as_json () {
    yq r --tojson "$(repo_root)/ci/pipelines/update_service_dependencies.yml"
}

function get_pipeline_services () {
    pipeline_as_json | jq -r -e '.resources.pipelines[].pipeline' | sort -u
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

function update_helm_repo () {
    az acr helm repo add -n "${ORIGIN_REPOSITORY}"
    helm repo update
    helm version
}

function get_helm_services_json () {
    helm search repo "${ORIGIN_REPOSITORY}" --devel -o json
}

function get_helm_services () {
    jq -r '.[].name' | sed -e 's|.*/||' -e 's|"$||' | sort -u
}

function services_are_subset () {
    # return true if lhs is a subset of rhs
    local -r lhs="${1}"
    local -r rhs="${2}"
    ! (diff <(printf '%s' "${lhs}") <(printf '%s' "${rhs}") | grep '^<')
}

function semver_breaking_change () {
    printf 'BREAKING CHANGE DETECTED\n'
    true
}

function semver_new_feature () {
    printf 'NEW FEATURE DETECTED\n'
    true
}

function has_breaking_changes () {
    local -r old_set="${1}"
    local -r new_set="${2}"
    false
}

function has_new_features () {
    local -r old_set="${1}"
    local -r new_set="${2}"
    false
}

function update_semver () {
    local locked_chart_services="${1}"
    local chart_services="${2}"
    local helm_services="${3}"

    if ! services_are_subset "${locked_chart_services}" "${chart_services}"; then
        # if locked_chart_services contains any service not in the chart, then breaking change
        semver_breaking_change
        return
    fi

    if services_are_subset "${locked_chart_services}" "${helm_services}"; then
        if has_breaking_changes "${locked_chart_services}" "${helm_services}"; then
            # if any service has a breaking change, then overall breaking change
            semver_breaking_change
            return
        fi
        if has_new_features "${locked_chart_services}" "${helm_services}"; then
            # if any service has a new feature, then overall new feature
            semver_new_feature
            return
        fi
    fi

    if ! services_are_subset "${chart_services}" "${locked_chart_services}"; then
        # if chart_services contains any service not in the locked_chart_services, then new feature
        semver_new_feature
        return
    fi
}

function check_services_config () {
    local upstream_services pipeline_services
    local chart_services locked_chart_services
    local helm_services_json helm_services
    upstream_services="$(get_upstream_services)"
    pipeline_services="$(get_pipeline_services)"
    chart_services="$(get_chart_services)"
    locked_chart_services="$(get_locked_chart_services)"
    helm_services_json="$(get_helm_services_json)"
    helm_services="$(get_helm_services <<< "${helm_services_json}")"
    printf 'upstream [%s]\n\n' "${upstream_services}"
    printf 'pipeline [%s]\n\n' "${pipeline_services}"
    printf 'chart [%s]\n\n' "${chart_services}"
    printf 'locked chart [%s]\n\n' "${locked_chart_services}"
    printf 'helm [%s]\n\n' "${helm_services}"
    if [[ "${pipeline_services}" != "${chart_services}" ]] ; then
        printf 'ERROR: misconfigured repository: upstream does not match update_service_dependencies.yml\n'
    elif [[ "${upstream_services}" != "${chart_services}" ]]; then
        printf 'ERROR: misconfigured repository: upstream does not match Chart.yaml\n'
    elif ! services_are_subset "${chart_services}" "${helm_services}"; then
        # if chart_services contains any service not in the helm_services, then ERROR
        printf 'ERROR: Chart.yaml refers to unpublished services\n'
    else
        update_semver "${locked_chart_services}" "${chart_services}" "${helm_services}"
        return
    fi
    false
}

function update_service_dependencies () {
    update_helm_repo
    if check_services_config; then
        # shellcheck disable=2046
        $(repo_root)/ci/recipes/update_umbrella_chart.sh
    else
        false
    fi
}

update_service_dependencies
