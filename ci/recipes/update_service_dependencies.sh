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

function filter_upstream_cf_service_semver () {
    local -r sub_chart="${1}"
    jq -r -e \
        --arg sub_chart "${sub_chart}" \
        '.dependencies[] | select(.name == "\($sub_chart)" ) | .version' \
      | sort -u
}

function locked_sub_chart_semver () {
    local -r sub_chart="${1}"
    yq r --tojson "$(chart_dir)/Chart.lock" | filter_upstream_cf_service_semver "${sub_chart}" || true
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

function internal_semver_file () {
    printf '%s/semver.txt' "$(repo_root)"
}

function internal_semver_file_json () {
    yq r "$(internal_semver_file)" --tojson
}

function internal_repo_semver () {
    jq -r '.semver' <(internal_semver_file_json)
}

function update_internal_repo_semver () {
    local -r requested_semver="${1}"
    local -r temp_file="$(mktemp)"
    internal_semver_file_json \
        | jq -r --arg new_semver "${requested_semver}" '.semver = $new_semver' \
        | yq r - > "${temp_file}"
    cp "${temp_file}" "$(internal_semver_file)"
    rm -f "${temp_file}"
    git add "$(internal_semver_file)"
}

function extract_semver_major () {
    cut -d '.' -f 1
}

function extract_semver_minor () {
    cut -d '.' -f 2
}

function semver_breaking_change () {
    local current_semver
    current_semver="$(internal_repo_semver)"
    printf 'BREAKING CHANGE DETECTED from semver[%s]\n' "${current_semver}"
    local major
    major="$(extract_semver_major <<< "${current_semver}")"
    (( major++ ))
    update_internal_repo_semver "${major}.0.0"
    printf '   to new semver[%s]\n' "$(internal_repo_semver)"
}
 
function semver_new_feature () {
    local current_semver
    current_semver="$(internal_repo_semver)"
    printf 'NEW FEATURE DETECTED from semver[%s]\n' "${current_semver}"
    local major minor
    major="$(extract_semver_major <<< "${current_semver}")"
    minor="$(extract_semver_minor <<< "${current_semver}")"
    (( minor++ ))
    update_internal_repo_semver "${major}.${minor}.0"
    printf '   to new semver[%s]\n' "$(internal_repo_semver)"
}

function get_helm_repo_semver() {
    local -r helm_services_json="${1}"
    local -r sub_chart="${2}"
    jq -r -e \
        --arg sub_chart "${sub_chart}" \
        '.[] | select(.name|test(".*\($sub_chart)$") ) | .version' \
      <<< "${helm_services_json}"
}

function test_breaking_changes () {
    local -r locked_semver="${1}"
    local -r helm_repo_semver="${2}"
    printf '  testing for breaking change from [%s] to [%s]\n' "${locked_semver}" "${helm_repo_semver}"
    local locked_major helm_major
    locked_major="$(extract_semver_major <<< "${locked_semver}")"
    helm_major="$(extract_semver_major <<< "${helm_repo_semver}")"
    if (( locked_major >> helm_major )); then
        printf 'Fatal regression detected in helm repository\n'
        exit 1
    fi
    (( locked_major < helm_major ))
}

function awk_update_dependency_semver_regex () {
    local -r sub_chart="${1}"
    local -r new_regex="${2}"
cat <<EOF
BEGIN {
    replacing=0
}

/name: '${sub_chart}/ { replacing = 1 }

replacing && /version:/ {
    version_line=\$0
    gsub(/'.*/,"", version_line)
    print version_line "'${new_regex}'"
    replacing = 0
    next
}

{ print }

EOF
}

function change_dependency_semver_regex () {
    local -r sub_chart="${1}"
    local -r new_regex="${2}"
    printf '  applying semver regex [%s] to sub chart [%s]\n' "${new_regex}" "${sub_chart}"
    local -r chart_file="$(chart_dir)/Chart.yaml"
    local -r temp_file="$(mktemp)"
    awk -f <(awk_update_dependency_semver_regex "${sub_chart}" "${new_regex}") \
        "${chart_file}" \
        > "${temp_file}"
    cp -f "${temp_file}" "${chart_file}"
    rm -f "${temp_file}"
    git add "${chart_file}"
}

function apply_breaking_change () {
    local -r sub_chart="${1}"
    local -r helm_semver="${2}"
    # update chart.yaml to have new semver regex for specified service chart
    local major new_regex
    major="$(extract_semver_major <<< "${helm_semver}")"
    new_regex="^${major}.0.0-0"
    change_dependency_semver_regex "${sub_chart}" "${new_regex}"
}

function has_breaking_changes () {
    local -r locked_chart_set="${1}"
    local sub_chart breaking_changes
    local helm_services_json
    breaking_changes=0
    helm_services_json="$(get_helm_services_json)"
    for sub_chart in ${locked_chart_set}; do
        printf 'examining chart [%s] for semver breaking changes\n' "${sub_chart}"
        local sub_chart_semver helm_repo_semver
        sub_chart_semver="$(locked_sub_chart_semver "${sub_chart}")"
        helm_repo_semver="$(get_helm_repo_semver "${helm_services_json}" "${sub_chart}")"
        if test_breaking_changes "${sub_chart_semver}" "${helm_repo_semver}" ; then
            apply_breaking_change "${sub_chart}" "${helm_repo_semver}"
            breaking_changes=1
        fi
    done
    (( breaking_changes == 1 ))
}

function test_new_features () {
    local -r locked_semver="${1}"
    local -r helm_repo_semver="${2}"
    printf '  testing for new feature from [%s] to [%s]\n' "${locked_semver}" "${helm_repo_semver}"
    local locked_major locked_minor helm_major helm_minor
    locked_major="$(extract_semver_major <<< "${locked_semver}")"
    locked_minor="$(extract_semver_minor <<< "${locked_semver}")"
    helm_major="$(extract_semver_major <<< "${helm_repo_semver}")"
    helm_minor="$(extract_semver_minor <<< "${helm_repo_semver}")"
    if (( locked_major >> helm_major )); then
        printf 'Fatal regression detected in helm repository\n'
        exit 1
    fi
    (( locked_major == helm_major )) && (( locked_minor << helm_minor ))
}

function has_new_features () {
    local -r locked_chart_set="${1}"
    local sub_chart new_features
    local helm_services_json
    new_features=0
    helm_services_json="$(get_helm_services_json)"
    for sub_chart in ${locked_chart_set}; do
        printf 'examining chart [%s] for semver new features\n' "${sub_chart}"
        local sub_chart_semver helm_repo_semver
        sub_chart_semver="$(locked_sub_chart_semver "${sub_chart}")"
        helm_repo_semver="$(get_helm_repo_semver "${helm_services_json}" "${sub_chart}")"
        if test_new_features "${sub_chart_semver}" "${helm_repo_semver}" ; then
            new_features=1
        fi
    done
    (( new_features == 1 ))
}

function update_semver () {
    local locked_chart_services="${1}"
    local helm_services="${2}"
    local chart_services="${3}"

    if ! services_are_subset "${locked_chart_services}" "${chart_services}"; then
        # if locked_chart_services contains any service not in the chart, then breaking change
        semver_breaking_change
        return
    fi

    if services_are_subset "${locked_chart_services}" "${helm_services}"; then
        if has_breaking_changes "${locked_chart_services}"; then
            # if any service has a breaking change, then overall breaking change
            semver_breaking_change
            return
        fi
        if has_new_features "${locked_chart_services}"; then
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
    elif ! [[ "${upstream_services}" != "${chart_services}" ]]; then
        printf 'ERROR: misconfigured repository: upstream does not match Chart.yaml\n'
    elif ! services_are_subset "${chart_services}" "${helm_services}"; then
        # if chart_services contains any service not in the helm_services, then ERROR
        printf 'ERROR: Chart.yaml refers to unpublished services\n'
    else
        update_semver "${locked_chart_services}" "${helm_services}" "${chart_services}"
        return
    fi
    false
}

function update_service_dependencies () {
    update_helm_repo
    if check_services_config; then
        # shellcheck disable=2046
        $(repo_root)/ci/recipes/update_umbrella_chart.sh
        false
    else
        false
    fi
}

update_service_dependencies
