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
        git tag -a "${blessed_release_tag}" -m "automated promotion on git commit" 'HEAD'
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

function get_pv_secret_namespace () {
    local -r deployment_json="${1}"
    jq -r -e '.k8s.pv_secret_namespace' <<< "${deployment_json}"
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

function get_migration_timeout () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.migration_timeout' <<< "${deployment_json}"
}

function get_helm_values () {
    local -r deployment_json="${1}"
    TARGET_CONFIG="$(get_target_config "${deployment_json}")" "$(repo_root)/recipes/extract_service_values.sh"
}

function get_cluster_config_json () {
    local -r deployment_json="${1}"
    TARGET_CONFIG="$(get_target_config "${deployment_json}")" "$(repo_root)/recipes/pre_process_strings.sh"
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

function create_k8s_app_namespace () {
    local -r deployment_json="${1}"
    local namespace
    namespace="$(get_kube_namespace "${deployment_json}")"
    kubectl --context "$(get_kube_context "${deployment_json}")" create namespace "${namespace}" || true
}

function create_pv_secret_namespace () {
    local -r deployment_json="${1}"
    local namespace
    namespace="$(get_pv_secret_namespace "${deployment_json}")"
    kubectl --context "$(get_kube_context "${deployment_json}")" create namespace "${namespace}" || true
}

function get_sa_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.storage.account.name' <<< "${deployment_json}"
}

function get_sa_key () {
    local -r sa_name="${1}"
    az storage account keys list --account-name "${sa_name}" | jq -r -e '.[0].value | @base64'
}

function get_certbot_state_name () {
    printf 'certbot-state'
}

function create_azure_secret_resource () {
    local -r deployment_json="${1}"
    local -r sa_name="${2}"
    local -r sa_key="${3}"
cat <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  annotations:
  labels:
    component: br-az-files-$(get_certbot_state_name)
    release: $(get_kube_namespace "${deployment_json}")
  name: br-az-files-$(get_certbot_state_name)
  namespace: $(get_pv_secret_namespace "${deployment_json}")
data:
  azurestorageaccountname: '$(base64 <<< "${sa_name}")'
  azurestorageaccountkey: '${sa_key}'

EOF
}

function create_azure_volume_secret () {
    local -r deployment_json="${1}"
    local sa_name sa_key
    sa_name="$(get_sa_name "${deployment_json}")"
    sa_key="$(get_sa_key "${sa_name}")"

    kubectl \
        --context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_pv_secret_namespace "${deployment_json}")" \
        apply -f <(create_azure_secret_resource "${deployment_json}" "${sa_name}" "${sa_key}")
}

function create_k8s_persistent_volume_resource () {
    local -r deployment_json="${1}"
    local -r sa_key="${2}"
cat <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: br-az-files-$(get_certbot_state_name)-$(get_kube_namespace "${deployment_json}")-pv
  labels:
    usage: br-az-files-$(get_certbot_state_name)-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: 'manual-certbot'
  mountOptions:
    - mfsymlinks
  azureFile:
    shareName: $(get_certbot_state_name)
    secretName: br-az-files-$(get_certbot_state_name)
    secretNamespace: $(get_pv_secret_namespace "${deployment_json}")
    readOnly: false
EOF
}

function create_k8s_persistent_volume () {
    local -r deployment_json="${1}"
    local sa_name sa_key
    sa_name="$(get_sa_name "${deployment_json}")"
    sa_key="$(get_sa_key "${sa_name}")"

    kubectl \
        --context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_kube_namespace "${deployment_json}")" \
        apply -f <(create_k8s_persistent_volume_resource "${deployment_json}" "${sa_key}")
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
    grep -iE 'fake|fixme|too2simple' <<< "${helm_values}"
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
        "$(get_helm_deployment_name "${deployment_json}" )" \
    || true
    if failed_secrets "${helm_values}" ; then
        printf 'FATAL: Failed to retrieve secrets needed in helm values!!\n'
        set -o xtrace
        ## fatal -- abort everyone
        kill SIGKILL $$
        set +o xtrace
    else
        helm upgrade \
            --install \
            --kube-context "$(get_kube_context "${deployment_json}")" \
            --namespace "$(get_kube_namespace "${deployment_json}")" \
            --history-max 200 \
            "$(get_helm_deployment_name "${deployment_json}" )" \
            "${registry}/${chart_name}" \
            --version "$(get_helm_version "${deployment_json}")" \
            --timeout "$(get_migration_timeout "${deployment_json}")" \
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

function deployment_helm_update () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    connect_to_k8s "${deployment_json}"
    create_k8s_app_namespace "${deployment_json}"
    create_pv_secret_namespace "${deployment_json}"
    create_azure_volume_secret "${deployment_json}"
    create_k8s_persistent_volume "${deployment_json}" || true
    update_helm_chart_on_k8s "${deployment_json}"
}

deployment_helm_update "${@}"
