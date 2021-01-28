#!/usr/bin/env bash
# usage: TARGET_CONFIG=target_environment_config.yaml create_eventhub_namespace_if_needed.sh eventhub_namespace

#
# Maintainer: techguru@byiq.com
#
# Copyright (c) 2017-2019,  Cloud Scaling -- All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# Exit script if you try to use an uninitialized variable.
set -o nounset

# Exit script if a statement returns a non-true return value.
set -o errexit

# Use the error status of the first failure, rather than that of the last item in a pipeline.
set -o pipefail

# Environment Variables
# ---------------------
declare -rx TARGET_CONFIG
declare -rx AZ_TRACE

# Arguments
# ---------------------
declare -rx kubernetes_cluster_name="${1}"

function kubernetes_cluster_name (){
    echo "${kubernetes_cluster_name}"
}

function repo_root () {
    git rev-parse --show-toplevel
}

function invoke_layer () {
    local -r layer="${1}"
    local -r target_recipe="${2}"
    shift 2
    "/bedrock/${layer}/recipes/${target_recipe}.sh" "$@"
}

function target_config () {
    printf '%s/%s' "$(repo_root)" "${TARGET_CONFIG}"
}

function paas_configuration () {
    yq read --tojson "$(target_config)" | jq -r -e '.target.paas'
}

function eventhub_namespace_json () {
    local -r namespace="${1}"
    jq -r -e --arg namespace "${namespace}" '.event_hub_namespaces.instances[]? | select(.name | test($namespace))'
}

function eventhub_topics () {
    local -r namespace_json="${1}"
    jq -r -e '[.topics[]? | select(.action == "create") | .name ] | @tsv' <<< "${namespace_json}"
}

function eventhub_topic () {
    local -r topic="${1}"
    jq -r -e --arg topic "${topic}" '.topics[]? | select(.name | test($topic))'
}

function eventhub_topic_exists () {
    local -r topic_json="${1}"
    az eventhubs eventhub show \
        --name "$(jq -r -e '.name' <<< "${topic_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${topic_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${topic_json}" )" \
    > /dev/null 2>&1
}

function show_blob_storage () {
  local capture_json="${1}"
  local storage_account blob_container
  storage_account="$(jq -r -e '.storage_account' <<< "${capture_json}" )"
  blob_container="$(jq -r -e '.blob_container' <<< "${capture_json}" )"
  az storage account show --name "${storage_account}"
  az storage container show --name "${blob_container}" --account-name "${storage_account}"
}


function update_eventhub_topic () {
    local topic_json="${1}"
    if [[ 'true' == "$(jq -r -e '.enable_capture' <<< "${topic_json}" )" ]]; then
        show_blob_storage "$(jq -r -e '.capture' <<< "${topic_json}" )"
        $AZ_TRACE eventhubs eventhub update \
            --name "$(jq -r -e '.name' <<< "${topic_json}" )" \
            --namespace-name "$(jq -r -e '.namespace' <<< "${topic_json}" )"\
            --resource-group "$(jq -r -e '.resource_group' <<< "${topic_json}" )" \
            --message-retention "$(jq -r -e '.message_retention' <<< "${topic_json}" )" \
            --partition-count "$(jq -r -e '.partition_count' <<< "${topic_json}" )" \
            --status "$(jq -r -e '.status' <<< "${topic_json}" )" \
            --enable-capture "$(jq -r -e '.enable_capture' <<< "${topic_json}" )" \
            --skip-empty-archives "$(jq -r -e '.capture.skip_empty_archives' <<< "${topic_json}" )" \
            --capture-interval "$(jq -r -e '.capture.capture_interval' <<< "${topic_json}" )" \
            --capture-size-limit "$(jq -r -e '.capture.capture_size_limit' <<< "${topic_json}" )" \
            --archive-name-format "$(jq -r -e '.capture.archive_name_format' <<< "${topic_json}" )" \
            --blob-container "$(jq -r -e '.capture.blob_container' <<< "${topic_json}" )" \
            --destination-name "$(jq -r -e '.capture.destination_name' <<< "${topic_json}" )" \
            --storage-account "$(jq -r -e '.capture.storage_account' <<< "${topic_json}" )"
    else
        $AZ_TRACE eventhubs eventhub update \
            --name "$(jq -r -e '.name' <<< "${topic_json}" )" \
            --namespace-name "$(jq -r -e '.namespace' <<< "${topic_json}" )"\
            --resource-group "$(jq -r -e '.resource_group' <<< "${topic_json}" )" \
            --message-retention "$(jq -r -e '.message_retention' <<< "${topic_json}" )" \
            --partition-count "$(jq -r -e '.partition_count' <<< "${topic_json}" )" \
            --status "$(jq -r -e '.status' <<< "${topic_json}" )" \
            --enable-capture "$(jq -r -e '.enable_capture' <<< "${topic_json}" )"
    fi
}

function create_eventhub_topic () {
    local -r topic_json="${1}"
    if [[ 'true' == "$(jq -r -e '.enable_capture' <<< "${topic_json}" )" ]]; then
        show_blob_storage "$(jq -r -e '.capture' <<< "${topic_json}" )"
        $AZ_TRACE eventhubs eventhub create \
            --name "$(jq -r -e '.name' <<< "${topic_json}" )" \
            --namespace-name "$(jq -r -e '.namespace' <<< "${topic_json}" )"\
            --resource-group "$(jq -r -e '.resource_group' <<< "${topic_json}" )" \
            --message-retention "$(jq -r -e '.message_retention' <<< "${topic_json}" )" \
            --partition-count "$(jq -r -e '.partition_count' <<< "${topic_json}" )" \
            --status "$(jq -r -e '.status' <<< "${topic_json}" )" \
            --enable-capture "$(jq -r -e '.enable_capture' <<< "${topic_json}" )" \
            --skip-empty-archives "$(jq -r -e '.capture.skip_empty_archives' <<< "${topic_json}" )" \
            --capture-interval "$(jq -r -e '.capture.capture_interval' <<< "${topic_json}" )" \
            --capture-size-limit "$(jq -r -e '.capture.capture_size_limit' <<< "${topic_json}" )" \
            --archive-name-format "$(jq -r -e '.capture.archive_name_format' <<< "${topic_json}" )" \
            --blob-container "$(jq -r -e '.capture.blob_container' <<< "${topic_json}" )" \
            --destination-name "$(jq -r -e '.capture.destination_name' <<< "${topic_json}" )" \
            --storage-account "$(jq -r -e '.capture.storage_account' <<< "${topic_json}" )"
    else
        $AZ_TRACE eventhubs eventhub create \
            --name "$(jq -r -e '.name' <<< "${topic_json}" )" \
            --namespace-name "$(jq -r -e '.namespace' <<< "${topic_json}" )"\
            --resource-group "$(jq -r -e '.resource_group' <<< "${topic_json}" )" \
            --message-retention "$(jq -r -e '.message_retention' <<< "${topic_json}" )" \
            --partition-count "$(jq -r -e '.partition_count' <<< "${topic_json}" )" \
            --status "$(jq -r -e '.status' <<< "${topic_json}" )" \
            --enable-capture "$(jq -r -e '.enable_capture' <<< "${topic_json}" )"
    fi
}

function eventhub_topic_consumer_groups () {
    local -r topic_json="${1}"
    jq -r -e '[.consumer_groups[]? | .name ] | @tsv' <<< "${topic_json}"
}

function eventhub_topic_consumer_group () {
    local -r consumer_group="${1}"
    jq -r -e --arg consumer_group "${consumer_group}" '.consumer_groups[]? | select(.name | test($consumer_group))'
}

function consumer_group_exists () {
    local -r consumer_group_json="${1}"
    az eventhubs eventhub consumer-group show \
        --name "$(jq -r -e '.name' <<< "${consumer_group_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${consumer_group_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${consumer_group_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${consumer_group_json}" )" \
    > /dev/null 2>&1
}

function update_consumer_group () {
    local -r consumer_group_json="${1}"
    $AZ_TRACE eventhubs eventhub consumer-group update \
        --name "$(jq -r -e '.name' <<< "${consumer_group_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${consumer_group_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${consumer_group_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${consumer_group_json}" )" \
        --user-metadata "$(jq -r -e '.user_metadata' <<< "${consumer_group_json}" )"
}

function create_consumer_group () {
    local -r consumer_group_json="${1}"
    $AZ_TRACE eventhubs eventhub consumer-group create \
        --name "$(jq -r -e '.name' <<< "${consumer_group_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${consumer_group_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${consumer_group_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${consumer_group_json}" )" \
        --user-metadata "$(jq -r -e '.user_metadata' <<< "${consumer_group_json}" )"
}

function create_or_update_consumer_group () {
    local -r consumer_group_json="${1}"
    if consumer_group_exists "${consumer_group_json}" ; then
        update_consumer_group "${consumer_group_json}"
    else
        create_consumer_group "${consumer_group_json}"
    fi
}

function create_or_update_consumer_groups () {
    local -r topic_json="${1}"
    for consumer_group in $(eventhub_topic_consumer_groups "${topic_json}" ); do
        create_or_update_consumer_group "$(eventhub_topic_consumer_group "${consumer_group}" <<< "${topic_json}" )"
    done
}

function eventhub_topic_authorization_rules () {
    local -r topic_json="${1}"
    jq -r -e '[.authorization_rules[]? | .name ] | @tsv' <<< "${topic_json}"
}

function eventhub_topic_authorization_rule () {
    local -r authorization_rule="${1}"
    jq -r -e --arg authorization_rule "${authorization_rule}" '.authorization_rules[]? | select(.name | test($authorization_rule))'
}

function authorization_rule_exists () {
    local -r authorization_rule_json="${1}"
    az eventhubs eventhub authorization-rule show \
        --name "$(jq -r -e '.name' <<< "${authorization_rule_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${authorization_rule_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${authorization_rule_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${authorization_rule_json}" )" \
    > /dev/null 2>&1
}

function update_authorization_rule () {
    local -r authorization_rule_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE eventhubs eventhub authorization-rule update \
        --name "$(jq -r -e '.name' <<< "${authorization_rule_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${authorization_rule_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${authorization_rule_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${authorization_rule_json}" )" \
        --rights $(jq -r -e '.rights' <<< "${authorization_rule_json}" )
}

function create_authorization_rule () {
    local -r authorization_rule_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE eventhubs eventhub authorization-rule  create \
        --name "$(jq -r -e '.name' <<< "${authorization_rule_json}" )" \
        --eventhub-name "$(jq -r -e '.topic_name' <<< "${authorization_rule_json}" )" \
        --namespace-name "$(jq -r -e '.namespace' <<< "${authorization_rule_json}" )"\
        --resource-group "$(jq -r -e '.resource_group' <<< "${authorization_rule_json}" )" \
        --rights $(jq -r -e '.rights' <<< "${authorization_rule_json}" )
}

function create_or_update_authorization_rule () {
    local -r authorization_rule_json="${1}"
    if authorization_rule_exists "${authorization_rule_json}" ; then
        update_authorization_rule "${authorization_rule_json}"
    else
        create_authorization_rule "${authorization_rule_json}"
    fi
}

function create_or_update_authorization_rules () {
    local topic_json="${1}"
    for authorization_rule in $(eventhub_topic_authorization_rules "${topic_json}" ); do
        create_or_update_authorization_rule "$(eventhub_topic_authorization_rule "${authorization_rule}" <<< "${topic_json}" )"
    done
}

function create_or_update_topic () {
    local -r topic_json="${1}"
    if eventhub_topic_exists "${topic_json}" ; then
        update_eventhub_topic "${topic_json}"
    else
        create_eventhub_topic "${topic_json}"
    fi
    create_or_update_consumer_groups "${topic_json}"
    create_or_update_authorization_rules "${topic_json}"
    authorize_managed_identities "${topic_json}"
}

function create_or_update_topics () {
    local -r namespace_json="${1}"
    for topic in $(eventhub_topics "${namespace_json}" ); do
        create_or_update_topic "$(eventhub_topic "${topic}" <<< "${namespace_json}" )"
    done
}

function authorize_managed_identities () {
    local -r namespace_json="${1}"
    printf '# UNIMPLEMENTED [%s]\n' "${FUNCNAME[0]}" > /dev/stderr
}

function eventhub_namespace_available () {
    local -r namespace_json="${1}"
    az eventhubs namespace exists \
        --name "$(jq -r -e '.name' <<< "${namespace_json}" )" \
    | jq -r -e '.nameAvailable'
}

function update_eventhub_namespace () {
    local -r namespace_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE eventhubs namespace update \
        --name "$(jq -r -e '.name' <<< "${namespace_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${namespace_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${namespace_json}" )" \
        --capacity "$(jq -r -e '.capacity' <<< "${namespace_json}" )" \
        --enable-auto-inflate "$(jq -r -e '.auto_inflate' <<< "${namespace_json}" )" \
        --enable-kafka "$(jq -r -e '.enable_kafka' <<< "${namespace_json}" )" \
        --maximum-throughput-units "$(jq -r -e '.maximum_throughput_units' <<< "${namespace_json}" )" \
        --default-action "$(jq -r -e '.network_rules_default_action' <<< "${namespace_json}" )" \
        --tags $(jq -r -e '.tags' <<< "${namespace_json}" )
}

function create_eventhub_namespace () {
    local -r namespace_json="${1}"
    # shellcheck disable=2046
    $AZ_TRACE eventhubs namespace create \
        --name "$(jq -r -e '.name' <<< "${namespace_json}" )" \
        --resource-group "$(jq -r -e '.resource_group' <<< "${namespace_json}" )" \
        --location "$(jq -r -e '.location' <<< "${namespace_json}" )" \
        --sku "$(jq -r -e '.sku' <<< "${namespace_json}" )" \
        --capacity "$(jq -r -e '.capacity' <<< "${namespace_json}" )" \
        --enable-auto-inflate "$(jq -r -e '.auto_inflate' <<< "${namespace_json}" )" \
        --enable-kafka "$(jq -r -e '.enable_kafka' <<< "${namespace_json}" )" \
        --maximum-throughput-units "$(jq -r -e '.maximum_throughput_units' <<< "${namespace_json}" )" \
        --default-action "$(jq -r -e '.network_rules_default_action' <<< "${namespace_json}" )" \
        --tags $(jq -r -e '.tags' <<< "${namespace_json}" )
}

function eventhub_namespace_firewall_policy () {
    local -r namespace_json="${1}"
    local rg location ns subscription
    rg="$(jq -r -e '.resource_group' <<< "${namespace_json}")"
    location="$(jq -r -e '.location' <<< "${namespace_json}" )"
    ns="$(jq -r -e '.name' <<< "${namespace_json}")"
    subscription="$(jq -r -e '.subscription' <<< "${namespace_json}")"
cat <<NAMESPACE_FIREWALL_POLICY
{
    "\$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "resources": [
        {
            "type": "Microsoft.EventHub/namespaces/networkRuleSets",
            "apiVersion": "2018-01-01-preview",
            "id": "/subscriptions/${subscription}/resourceGroups/${rg}/providers/Microsoft.EventHub/namespaces/${ns}/networkRuleSets/default",
            "name": "${ns}/default",
            "location": "${location}",
            "properties": {
                "defaultAction": "Allow",
                "virtualNetworkRules": [],
                "ipRules": []
            }
        }
    ]
}
NAMESPACE_FIREWALL_POLICY
}

function update_eventhub_namespace_firewall_policy () {
    local -r namespace_json="${1}"
    $AZ_TRACE deployment group create \
        --resource-group "$(jq -r -e '.resource_group' <<< "${namespace_json}" )" \
        --template-file <(eventhub_namespace_firewall_policy "${namespace_json}" )
}


function create_or_update_eventhub_namespace () {
    local -r namespace_json="${1}"
    if [[ "$(eventhub_namespace_available "${namespace_json}" )" == 'true' ]]; then
        create_eventhub_namespace "${namespace_json}"
    else
        update_eventhub_namespace "${namespace_json}"
    fi
    create_or_update_topics "${namespace_json}"
    update_eventhub_namespace_firewall_policy "${namespace_json}"
}

function create_eventhub_namespace_if_needed () {
    local -r namespace="${1}"
    local namespace_json
    namespace_json="$(paas_configuration | eventhub_namespace_json "${namespace}")"
    printf 'Creating or Updating EventHub Namespace [%s]\n' "${namespace}" > /dev/stderr
    create_or_update_eventhub_namespace "${namespace_json}"
}

create_eventhub_namespace_if_needed "$@"
