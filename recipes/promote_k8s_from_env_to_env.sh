#!/usr/bin/env bash
# usage: promote_k8s_from_env_to_env.sh

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

function repo_root () {
    git rev-parse --show-toplevel
}

function is_azure_pipeline_build () {
    [[ "True" == "${TF_BUILD:-}" ]]
}

function update_git_tag () {
    local -r blessed_release_tag="${1}"
    if [[ "true" == "${BUMP_SEMVER}" ]]; then
        printf 'pushing git commits: \n'
        git status
        git tag -a "${blessed_release_tag}" -m "automated promotion on git commit"
        git push origin "${blessed_release_tag}"
    fi
}

function get_kube_context () {
    local -r deployment_json="${1}"
    jq -r -e '.k8s.context' <<< "${deployment_json}"
}

function get_kube_namespace () {
    local -r deployment_json="${1}"
    jq -r -e '.k8s.namespace' <<< "${deployment_json}"
}

function get_helm_deployment_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.deployment_name' <<< "${deployment_json}"
}

function get_helm_registry () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.registry' <<< "${deployment_json}"
}

function get_helm_chart_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.name' <<< "${deployment_json}"
}

function get_helm_version () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.version' <<< "${deployment_json}"
}

function get_target_config () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.config' <<< "${deployment_json}"
}

function get_environment_suffix () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.suffix' <<< "${deployment_json}"
}

function get_helm_values () {
    local -r deployment_json="${1}"
    TARGET_CONFIG="$(get_target_config "${deployment_json}")" "$(repo_root)/recipes/extract_service_values.sh"
}

function get_cluster_config_json () {
    local -r deployment_json="${1}"
    yq r --tojson "$(repo_root)/$(get_target_config "${deployment_json}")"
}

function connect_to_k8s () {
    local -r deployment_json="${1}"
    local cluster_config_json subscription resource_group cluster_name
    cluster_config_json="$(get_cluster_config_json "${deployment_json}" )"
    subscription="$(jq -r -e '.target.metadata.default_azure_subscription' <<< "${cluster_config_json}")"
    resource_group="$(jq -r -e '.target.paas.k8s.clusters[0].resource_group' <<< "${cluster_config_json}")"
    cluster_name="$(jq -r -e '.target.paas.k8s.clusters[0].name' <<< "${cluster_config_json}")"
    az aks get-credentials \
        --subscription "${subscription}" \
        --resource-group "${resource_group}" \
        --name "${cluster_name}" \
        --overwrite-existing \
        --admin
}

function update_helm_repo () {
    local -r registry="${1}"
    az acr helm repo add --name "${registry}"
    helm repo update
    helm version
}

function failed_secrets () {
    local -r helm_values="${1}"
    #printf 'Evaluating helm values [\n%s\n]\n' "${helm_values}"
    grep -iE 'fixme|too2simple' <<< "${helm_values}"
}

function update_helm_chart_on_k8s () {
    local -r deployment_json="${1}"
    local registry chart_name
    registry="$(get_helm_registry "${deployment_json}")"
    chart_name="$(get_helm_chart_name "${deployment_json}")"
    update_helm_repo "${registry}"
    printf 'Script Failure means unable to access key vault\n'
    # get_helm_values "${deployment_json}"
    helm_values="$(get_helm_values "${deployment_json}")"
    printf 'Script succeeded to access key vault\n'
    kubectl cluster-info
    helm list -A \
        --kube-context "$(get_kube_context "${deployment_json}")"
    helm history \
        --kube-context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_kube_namespace "${deployment_json}")" \
        "$(get_helm_deployment_name "${deployment_json}" )"
    if failed_secrets "${helm_values}" ; then
        printf 'FATAL: Failed to retrieve secrets needed in helm values!!\n'
        set -o xtrace
        ## fatal -- abort everyone
        kill SIGKILL $$
        set +o xtrace
    else
        helm upgrade \
            --kube-context "$(get_kube_context "${deployment_json}")" \
            --namespace "$(get_kube_namespace "${deployment_json}")" \
            "$(get_helm_deployment_name "${deployment_json}" )" \
            "${registry}/${chart_name}" \
            --version "$(get_helm_version "${deployment_json}")" \
            --debug --dry-run \
            --values <(cat <<< "${helm_values}")
        helm upgrade \
            --kube-context "$(get_kube_context "${deployment_json}")" \
            --namespace "$(get_kube_namespace "${deployment_json}")" \
            "$(get_helm_deployment_name "${deployment_json}" )" \
            "${registry}/${chart_name}" \
            --version "$(get_helm_version "${deployment_json}")" \
            --timeout 30m \
            --wait \
            --values <(cat <<< "${helm_values}")
    fi
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(repo_root)/configuration/deployments/cf_deployments.yaml" |
        jq -r -e \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

function get_latest_deployed_charts () {
    local -r origin_deployment_json="${1}"
    local origin_deployment_name
    origin_deployment_name="$(get_helm_deployment_name "${origin_deployment_json}" )"
    connect_to_k8s "${origin_deployment_json}" > /dev/null 2>&1 || true
    helm list \
        --kube-context "$(get_kube_context "${origin_deployment_json}")" \
        --namespace "$(get_kube_namespace "${origin_deployment_json}")" \
        -o json
}

function get_latest_full_chart_name () {
    local origin_deployment_json="${1}"
    local origin_deployment_name
    origin_deployment_name="$(get_helm_deployment_name "${origin_deployment_json}" )"
    get_latest_deployed_charts "${origin_deployment_json}" | tee /dev/stderr | \
        jq -r -e \
            --arg deployment_name "${origin_deployment_name}" \
            '.[] | select(.name == "\($deployment_name)") | .chart' | tee /dev/stderr
}

function get_latest_deployed_version () {
    local origin_deployment_json="${1}"
    local origin_chart_name
    origin_chart_name="$(get_helm_chart_name "${origin_deployment_json}" )"
    get_latest_full_chart_name "${origin_deployment_json}" | \
        sed -e "s|^${origin_chart_name}-||"
}

function fetch_latest_deployed_chart () {
    local origin_deployment_json="${1}"
    local tmp_chart_dir="${2}"
    registry="$(get_helm_registry "${origin_deployment_json}")"
    chart_name="$(get_helm_chart_name "${origin_deployment_json}")"
    update_helm_repo "${registry}"
    helm fetch \
        "${registry}/${chart_name}" \
        --destination "${tmp_chart_dir}" \
        --untar \
        --version "$(get_latest_deployed_version "${origin_deployment_json}" )"
}

function extract_chart_appversion () {
    local theChartfile="${1}"
    grep -i '^appVersion:' "${theChartfile}" | sed -e 's|.*: ||'
}

function extract_chart_version () {
    local theChartfile="${1}"
    grep -i '^version:' "${theChartfile}" | sed -e 's|.*: ||'
}

function find_container_references () {
    local -r origin_registry="${1}"
    find . -name "values.yaml" -exec grep -iH "${origin_registry}.azurecr.io" {} \;
}

function copy_one_container () {
    local -r container_ref="${1}"
    local -r origin_registry="${2}"
    local -r target_registry="${3}"
    local -r origin_suffix="${4}"
    local -r target_suffix="${5}"

    local container_origin_repo container_target_repo
    local values_file values_dir chart_file
    local container_version target_container_version
    # shellcheck disable=2001
    values_file="$(sed -e 's|:.*||g' <<< "${container_ref}")"
    # shellcheck disable=2001
    values_dir="$(sed -e 's|/values.yaml.*$||' <<< "${values_file}")"
    chart_file="${values_dir}/Chart.yaml"
    printf '[%s]\n  [%s]\n   [%s]\n' "${values_file}" "${values_dir}" "${chart_file}"
    container_version="$(extract_chart_appversion "${chart_file}")"
    target_container_version="$(sed -e "s|${origin_suffix}|${target_suffix}|" <<< "${container_version}")"
    # shellcheck disable=2001
    container_origin_repo="$(sed -e "s|.* '||" -e "s|'$||" <<< "${container_ref}")"
    # shellcheck disable=2001
    container_target_repo="$(sed -e "s|${origin_registry}|${target_registry}|" <<< "${container_origin_repo}")"
    docker pull "${container_origin_repo}:${container_version}"
    docker tag "${container_origin_repo}:${container_version}" "${container_target_repo}:${target_container_version}"
    docker push "${container_target_repo}:${target_container_version}"
}

function acr_login () {
    local -r desired_repo="${1}"
    if ! is_azure_pipeline_build; then
        az acr login -n "${desired_repo}" 2> /dev/null
    fi
}

function copy_containers_from_list () {
    local -r origin_registry="${1}"
    local -r target_registry="${2}"
    local -r origin_suffix="${3}"
    local -r target_suffix="${4}"

    acr_login "${origin_registry}"
    acr_login "${target_registry}"

    local line_data
    while IFS=$'\n' read -r line_data; do
        local current_line="${line_data}"
        printf '%s\n' "${current_line}"
        copy_one_container \
            "${current_line}" \
            "${origin_registry}" \
            "${target_registry}" \
            "${origin_suffix}" \
            "${target_suffix}"
    done
}

function copy_containers () {
    local -r origin_deployment_json="${1}"
    local -r target_deployment_json="${2}"
    local -r origin_suffix="${3}"
    local -r target_suffix="${4}"
    local origin_registry target_registry
    origin_registry="$(get_helm_registry "${origin_deployment_json}")"
    target_registry="$(get_helm_registry "${target_deployment_json}")"
    find_container_references "${origin_registry}" \
        | copy_containers_from_list \
            "${origin_registry}" \
            "${target_registry}" \
            "${origin_suffix}" \
            "${target_suffix}"
}

function rewrite_files () {
    local -r filename="${1}"
    local -r replace_string="${2}"
    local -r replacement="${3}"
    local eachFile
    # shellcheck disable=2044
    for eachFile in $(find . -name "${filename}"); do
        local tmp_file
        tmp_file="$(mktemp)"
        sed -e "s|${replace_string}|${replacement}|" "${eachFile}" > "${tmp_file}"
        cp "${tmp_file}" "${eachFile}"
        rm -f "${tmp_file}"
    done
}

function package_and_publish_new_umbrella () {
    local -r target_registry="${1}"
    local -r chart_name="${2}"
    local chart_package
    chart_package="${chart_name}-$(extract_chart_version "./Chart.yaml").tgz"

    az acr helm repo add --name "${target_registry}"
    helm package .
    ls -l
    printf 'chart package name [%s]\n' "${chart_package}"
    if az acr helm push -n "${target_registry}" "${chart_package}" 2> /dev/null; then
        result=0
    else
        printf 'Race condition resolved in favor of earlier job\n'
        result=1
    fi
    (( result == 0 ))
}

function rewrite_latest_deployment () {
    local -r origin_deployment_json="${1}"
    local -r target_deployment_json="${2}"
    local -r tmp_chart_dir="${3}"
    local origin_chart_name origin_registry target_registry
    origin_chart_name="$(get_helm_chart_name "${origin_deployment_json}" )"
    origin_registry="$(get_helm_registry "${origin_deployment_json}")"
    target_registry="$(get_helm_registry "${target_deployment_json}")"
    origin_suffix="-$(get_environment_suffix "${origin_deployment_json}")"
    target_suffix="-$(get_environment_suffix "${target_deployment_json}")"
    pushd "${tmp_chart_dir}/${origin_chart_name}"
        rm -f "Chart.lock"
        copy_containers "${origin_deployment_json}" "${target_deployment_json}" "${origin_suffix}" "${target_suffix}"
        rewrite_files 'Chart.yaml' "${origin_suffix}" "${target_suffix}"
        rewrite_files 'values.yaml' "${origin_registry}" "${target_registry}"
        package_and_publish_new_umbrella "${target_registry}" "${origin_chart_name}"
    popd
}

function promote_k8s_from_env_to_env () {
    local -r origin_deployment_name="${1}"
    local -r target_deployment_name="${2}"
    local origin_deployment_json target_deployment_json tmp_chart_dir
    origin_deployment_json="$(get_deployment_json_by_name "${origin_deployment_name}")"
    target_deployment_json="$(get_deployment_json_by_name "${target_deployment_name}")"
    if tmp_chart_dir="$(mktemp -d)"; then
        fetch_latest_deployed_chart "${origin_deployment_json}" "${tmp_chart_dir}"
        rewrite_latest_deployment "${origin_deployment_json}" "${target_deployment_json}"  "${tmp_chart_dir}"
        printf 'tmp_chart_dir[%s]\n' "${tmp_chart_dir}"
        update_helm_chart_on_k8s "${target_deployment_json}"
        #rm -rf "${tmp_chart_dir}"
    fi
}

promote_k8s_from_env_to_env "${@}"
