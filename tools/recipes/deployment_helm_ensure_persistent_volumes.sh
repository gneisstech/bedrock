#!/usr/bin/env bash
# usage: deployment_helm_ensure_persistent_volumes.sh

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

function get_app () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.app' <<< "${deployment_json}"
}

function get_env () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.name' <<< "${deployment_json}"
}

function get_volume_prefix () {
    local -r deployment_json="${1}"
    jq -r -e '.environment.volume_prefix' <<< "${deployment_json}"
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

function get_helm_chart_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.name' <<< "${deployment_json}"
}

function get_helm_version () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.umbrella.version' <<< "${deployment_json}"
}

function get_migration_timeout () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.migration_timeout' <<< "${deployment_json}"
}

function get_helm_values () {
    local -r deployment_json="${1}"
    "/bedrock/recipes/extract_service_values.sh" "${deployment_json}"
}

function get_cluster_config_json () {
    local -r deployment_json="${1}"
    "/bedrock/recipes/pre_process_strings.sh" "${deployment_json}"
}

function get_sa_name () {
    local -r deployment_json="${1}"
    jq -r -e '.helm.storage.account.name' <<< "${deployment_json}"
}

function get_sa_key () {
    local -r sa_name="${1}"
    az storage account keys list --account-name "${sa_name}" | jq -r -e '.[0].value | @base64'
}

function create_azure_file_volume_secret_resource () {
    local -r deployment_json="${1}"
    local -r sa_name="${2}"
    local -r sa_key="${3}"
    local -r volume_name="${4}"
    local -r volume_prefix="${5}"

printf "\n\n===[%s]===\n\n" "${sa_name}" > /dev/stderr
printf "\n\n===[%s]===\n\n" "$(echo -n "${sa_name}" | base64)" > /dev/stderr

cat <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  annotations:
  labels:
    component: ${volume_prefix}-az-files-${volume_name}
    release: $(get_kube_namespace "${deployment_json}")
  name: ${volume_prefix}-az-files-${volume_name}
  namespace: $(get_pv_secret_namespace "${deployment_json}")
data:
  azurestorageaccountname: '$(echo -n "${sa_name}" | base64)'
  azurestorageaccountkey: '${sa_key}'

EOF
}

function create_azure_file_volume_secret () {
    local -r deployment_json="${1}"
    local -r sa_name="${2}"
    local -r volume_name="${3}"
    local -r volume_prefix="${4}"
    local sa_key
    sa_key="$(get_sa_key "${sa_name}")"

    kubectl \
        --context "$(get_kube_context "${deployment_json}")" \
        --namespace "$(get_pv_secret_namespace "${deployment_json}")" \
        apply -f <( \
          create_azure_file_volume_secret_resource \
            "${deployment_json}" \
            "${sa_name}" \
            "${sa_key}" \
            "${volume_name}" \
            "${volume_prefix}" \
        )
}

function create_k8s_persistent_file_volume_resource () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_quota="${4}"

cat <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${volume_prefix}-az-files-${volume_name}-$(get_kube_namespace "${deployment_json}")-pv
  labels:
    usage: ${volume_prefix}-az-files-${volume_name}-pv
spec:
  capacity:
    storage: ${volume_quota}Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: 'manual-${volume_name}'
  azureFile:
    shareName: ${volume_name}
    secretName: ${volume_prefix}-az-files-${volume_name}
    secretNamespace: $(get_pv_secret_namespace "${deployment_json}")
    readOnly: false
  mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
  #    - cache=strict
  #    - nosharesock
EOF

cat > /dev/null <<EOF2
  xx-mountOptions:
    - dir_mode=0777
    - file_mode=0777
    - uid=0
    - gid=0
    - cache=strict
    - mfsymlinks
EOF2
}

function create_k8s_persistent_file_volume_claim () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_quota="${4}"

cat <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${volume_prefix}-az-files-${volume_name}-$(get_kube_namespace "${deployment_json}")-pvc
  namespace: $(get_kube_namespace "${deployment_json}")
  labels:
    usage: ${volume_prefix}-az-files-${volume_name}-pvc
spec:
  resources:
    requests:
      storage: ${volume_quota}Gi
  accessModes:
    - ReadWriteMany
  storageClassName: 'manual-${volume_name}'
  volumeMode: 'Filesystem'
  volumeName: ${volume_prefix}-az-files-${volume_name}-$(get_kube_namespace "${deployment_json}")-pv
EOF
}

function create_k8s_persistent_file_volume () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_quota="${4}"
    local -r create_pv="${5}"
    local -r create_pvc="${6}"

    if [[ 'true' == "${create_pv}" ]]; then
      kubectl \
          --context "$(get_kube_context "${deployment_json}")" \
          --namespace "$(get_kube_namespace "${deployment_json}")" \
          apply -f <( \
            create_k8s_persistent_file_volume_resource \
              "${deployment_json}" \
              "${volume_name}" \
              "${volume_prefix}" \
              "${volume_quota}" \
          )
    fi

    if [[ 'true' == "${create_pvc}" ]]; then
      kubectl \
          --context "$(get_kube_context "${deployment_json}")" \
          --namespace "$(get_kube_namespace "${deployment_json}")" \
          apply -f <( \
            create_k8s_persistent_file_volume_claim \
              "${deployment_json}" \
              "${volume_name}" \
              "${volume_prefix}" \
              "${volume_quota}" \
          )
    fi
}

function get_deployment_json_by_name () {
    local -r deployment_name="${1}"
    "/bedrock/recipes/get_deployment_json_by_name.sh" "${deployment_name}"
}

function get_file_volume_metadata_by_name () {
    local -r cluster_config_json="${1}"
    local -r volume_name="${2}"
    jq -r -e \
      --arg volume_name "${volume_name}" \
      '.target.paas.storage.azure_files[] | select(.name == "\($volume_name)")' <<< "${cluster_config_json}"
}

function create_artifacts_for_pv_az_file_volume () {
    local -r deployment_json="${1}"
    local -r volume_metadata="${2}"
    local volume_name volume_quota volume_prefix sa_name create_pv create_pvc
    volume_name="$(jq -r -e '.name' <<< "${volume_metadata}")"
    volume_quota="$(jq -r -e '.quota' <<< "${volume_metadata}")"
    volume_prefix="$(get_volume_prefix "${deployment_json}")"
    sa_name="$(jq -r -e '.storage_account_name' <<< "${volume_metadata}")"
    create_pv="$(jq -r '.pv.create // "false"' <<< "${volume_metadata}" )"
    create_pvc="$(jq -r '.pvc.create // "false"' <<< "${volume_metadata}" )"

    create_azure_file_volume_secret \
      "${deployment_json}" \
      "${sa_name}" \
      "${volume_name}" \
      "${volume_prefix}"
    create_k8s_persistent_file_volume \
      "${deployment_json}" \
      "${volume_name}" \
      "${volume_prefix}" \
      "${volume_quota}" \
      "${create_pv}" \
      "${create_pvc}" \
    || true
}

function iterate_az_file_volumes () {
    local -r deployment_json="${1}"
    local cluster_config_json volumes
    cluster_config_json="$(get_cluster_config_json "${deployment_json}" )"
    volumes="$(jq -r '.target.paas.storage.azure_files[]? | .name // empty' <<< "${cluster_config_json}")"
    for volume_name in ${volumes}; do
        local volume_metadata
        volume_metadata="$(get_file_volume_metadata_by_name "${cluster_config_json}" "${volume_name}")"
        create_artifacts_for_pv_az_file_volume "${deployment_json}" "${volume_metadata}" || true
    done
}

function create_k8s_persistent_disk_volume_resource () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_spec="${4}"

cat <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${volume_prefix}-az-disks-${volume_name}-$(get_kube_namespace "${deployment_json}")-pv
  labels:
    usage: ${volume_prefix}-az-disks-${volume_name}-pv
spec:
  ${volume_spec}
EOF
}

function create_k8s_persistent_disk_volume_claim () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_spec="${4}"
    local volume_quota
    volume_quota="$(jq -r -e '.capacity.storage' <<< "${volume_spec}")"

cat <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${volume_prefix}-az-disks-${volume_name}-$(get_kube_namespace "${deployment_json}")-pvc
  namespace: $(get_kube_namespace "${deployment_json}")
  labels:
    usage: ${volume_prefix}-az-disks-${volume_name}-pvc
spec:
  resources:
    requests:
      storage: ${volume_quota}
  accessModes:
    - ReadWriteOnce
  storageClassName: '${volume_name}'
  volumeMode: 'Filesystem'
  volumeName: ${volume_prefix}-az-disks-${volume_name}-$(get_kube_namespace "${deployment_json}")-pv
EOF
}

function create_k8s_persistent_disk_volume () {
    local -r deployment_json="${1}"
    local -r volume_name="${2}"
    local -r volume_prefix="${3}"
    local -r volume_spec="${4}"
    local -r create_pv="${5}"
    local -r create_pvc="${6}"

    if [[ 'true' == "${create_pv}" ]]; then
      kubectl \
          --context "$(get_kube_context "${deployment_json}")" \
          --namespace "$(get_kube_namespace "${deployment_json}")" \
          apply -f <( \
            create_k8s_persistent_disk_volume_resource \
              "${deployment_json}" \
              "${volume_name}" \
              "${volume_prefix}" \
              "${volume_spec}" \
          )
    fi

    if [[ 'true' == "${create_pvc}" ]]; then
      kubectl \
          --context "$(get_kube_context "${deployment_json}")" \
          --namespace "$(get_kube_namespace "${deployment_json}")" \
          apply -f <( \
            create_k8s_persistent_disk_volume_claim \
              "${deployment_json}" \
              "${volume_name}" \
              "${volume_prefix}" \
              "${volume_spec}" \
          )
    fi
}

function get_disk_volume_metadata_by_name () {
    local -r cluster_config_json="${1}"
    local -r volume_name="${2}"
    jq -r -e \
      --arg volume_name "${volume_name}" \
      '.target.paas.storage.azure_disks[] | select(.name == "\($volume_name)")' <<< "${cluster_config_json}"
}

function create_artifacts_for_pv_az_disk_volume () {
    local -r deployment_json="${1}"
    local -r volume_metadata="${2}"
    local volume_name volume_quota volume_prefix volume_spec create_pv create_pvc
    volume_name="$(jq -r -e '.name' <<< "${volume_metadata}")"
    volume_quota="$(jq -r -e '.quota' <<< "${volume_metadata}")"
    volume_prefix="$(get_volume_prefix "${deployment_json}")"
    volume_spec="$(jq -r -e '.k8s_volume_data' <<< "${volume_metadata}")"
    create_pv="$(jq -r '.pv.create // "false"' <<< "${volume_metadata}" )"
    create_pvc="$(jq -r '.pvc.create // "false"' <<< "${volume_metadata}" )"

    create_k8s_persistent_disk_volume \
      "${deployment_json}" \
      "${volume_name}" \
      "${volume_prefix}" \
      "${volume_spec}" \
      "${create_pv}" \
      "${create_pvc}" \
    || true
}

function iterate_az_disk_volumes () {
    local -r deployment_json="${1}"
    local cluster_config_json volumes
    cluster_config_json="$(get_cluster_config_json "${deployment_json}" )"
    volumes="$(jq -r '.target.paas.storage.azure_disks[]? | .name // empty' <<< "${cluster_config_json}")"
    for volume_name in ${volumes}; do
        local volume_metadata
        volume_metadata="$(get_disk_volume_metadata_by_name "${cluster_config_json}" "${volume_name}")"
        create_artifacts_for_pv_az_disk_volume "${deployment_json}" "${volume_metadata}" || true
    done
}

function deployment_helm_ensure_persistent_volumes () {
    local -r deployment_name="${1}"
    local deployment_json
    deployment_json="$(get_deployment_json_by_name "${deployment_name}")"
    iterate_az_file_volumes "${deployment_json}"
    iterate_az_disk_volumes "${deployment_json}"
}

deployment_helm_ensure_persistent_volumes "${@}"
