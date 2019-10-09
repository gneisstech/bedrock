#!/usr/bin/env bash
# usage: register_application_if_needed.sh service_name

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx TARGET_CONFIG

# Arguments
# ---------------------
declare -rx SERVICE_GROUP="${1}"

function service_group (){
    echo "${SERVICE_GROUP}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
    local -r layer="${1}"
    local -r target_recipe="${2}"
    shift 2
    "$(repo_root)/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    echo "$(repo_root)/${TARGET_CONFIG}"
}

function saas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.saas'
}

function svc_attr () {
    local -r attr="${1}"
    saas_configuration | jq -r -e ".${SERVICE_GROUP} | .${attr} // empty"
}

function svc_string () {
    local -r attr="${1}"
    local -r key="${2}"
    svc_attr "${attr}" | jq -r -e ".${key} | if type==\"array\" then join(\"\") else . end"
}

function svc_strings () {
    local -r attr="${1}"
    local -r key="${2}"
    svc_attr "${attr}" | jq -r -e ".${key} as \$config | \$config | [ keys[] | \"\(.)=\(\$config[.] | if type==\"array\" then join(\"\") else . end  )\" ] | @tsv"
}

function get_vault_secret () {
    local -r vault="${1}"
    local -r secret_name="${2}"
    az keyvault secret show \
        --vault-name "${vault}" \
        --name "${secret_name}" \
    | jq -r '.value'
}

function get_current_subscription () {
    az account show | jq -r '.id'
}

function existing_reply_urls () {
    az ad app show --id "$(svc_attr 'application_id')" | jq -r -e '.replyUrls'
}

function add_to_jq_array () {
    local -r newElements="${1}"
    jq -r -e ". += [ \"${newElements}\" ]"
}

function new_reply_urls () {
    existing_reply_urls | add_to_jq_array "$(svc_string 'variables' 'app_auth_callback_url')"
}

function new_reply_urls_array () {
    new_reply_urls | jq -r -e '@tsv'
}

function add_reply_url_to_application_if_needed () {
    # shellcheck disable=SC2046
    echo az ad app update \
        --subscription "${previous_subscription}" \
        --id "$(svc_attr 'application_id')" \
        --reply_urls $(new_reply_urls_array)
}

function add_client_secret_to_application () {
    local -r previous_subscription="${1}"
    local secret
    az account set --subscription "${previous_subscription}"
    secret="$(get_vault_secret "$(svc_attr 'client_secret.vault')" "$(svc_attr 'client_secret.secret_name')" )"
    if [[ -n "${secret}" ]]; then
        az account set --subscription "$(svc_attr 'tenant')"
        echo az ad app update \
            --subscription "${previous_subscription}" \
            --id "$(svc_attr 'application_id')" \
            --credential-description "$(svc_attr 'client_secret.secret_name')" \
            --password "${secret}"
    fi
    az account set --subscription "${previous_subscription}"
}

function update_target_application () {
    local -r previous_subscription="${1}"
    az account set --subscription "$(svc_attr 'tenant')"
    add_reply_url_to_application_if_needed
    add_client_secret_to_application "${previous_subscription}"
    az account set --subscription "${previous_subscription}"
}

function register_application_if_needed () {
    update_target_application "${previous_subscription}"
}

#
# word to the wise, run `az login --allow-no-subscriptions` or equivalent before running this script
#


previous_subscription="$(get_current_subscription)"
function restore_subscription () {
    az account set --subscription "${previous_subscription}"
}
trap restore_subscription 0

( register_application_if_needed )


