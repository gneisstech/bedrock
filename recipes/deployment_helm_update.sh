#!/usr/bin/env bash
# usage: deploy_umbrella_chart_to_dev.sh

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
        --admin
}

function update_helm_repo () {
    local -r registry="${1}"
    az acr helm repo add --name "${registry}"
    helm repo update
    helm version
}

function update_helm_chart_on_k8s () {
    local -r deployment_json="${1}"
    local registry chart_name
    registry="$(get_helm_registry "${deployment_json}")"
    chart_name="$(get_helm_chart_name "${deployment_json}")"
    update_helm_repo "${registry}"
    kubectl cluster-info
    helm list -A \
        --kube-context "$(get_kube_context "${deployment_json}")"
    helm history \
        --kube-context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_kube_namespace "${deployment_json}")" \
        "$(get_helm_deployment_name "${deployment_json}" )"
    helm upgrade \
        --kube-context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_kube_namespace "${deployment_json}")" \
        "$(get_helm_deployment_name "${deployment_json}" )" \
        "${registry}/${chart_name}" \
        --version "$(get_helm_version "${deployment_json}")" \
        --values <(get_helm_values "${deployment_json}")
        # --dry-run --debug | tee foo.log
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    yq r --tojson "$(repo_root)/configuration/deployments/cf_deployments.yaml" |
        jq -r -e \
            --arg deployment_name "${deployment_name}" \
            '.deployments[] | select(.name == "\($deployment_name)")'
}

function deployment_helm_update () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    connect_to_k8s "${deployment_json}"
    update_helm_chart_on_k8s "${deployment_json}"
}

deployment_helm_update "${@}"
