#!/usr/bin/env bash
# usage: create_application_gateway_if_needed.sh application_gateway_name

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
declare -rx APPLICATION_GATEWAY_NAME="${1}"

function application_gateway_name (){
    echo "${APPLICATION_GATEWAY_NAME}"
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

function gw_attr () {
    local -r attr="${1}"
    saas_configuration | jq -r -e ".application_gateways[] | select(.name == \"$(application_gateway_name)\") | .${attr}"
}

function application_gateway_resource_group () {
    gw_attr 'resource_group'
}

function application_gateway_already_exists () {
    az network application-gateway show \
        --name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        > /dev/null 2>&1
}

function foo3 () {
cat <<END3
    --cert-file "$(gw_attr '')" \
    --cert-password "$(gw_attr '')"
END3
}

function options_list_if_present () {
    local -r option_key="${1}"
    local -r option_config="${2}"
    local option_value
    option_value="$(gw_attr "${option_config}" | jq -r -e '@tsv')"
    if [[ -n "${option_value}" ]]; then
        echo -n "--${option_key} ${option_value}"
    fi
}

function deploy_application_gateway () {
    #  shellcheck disable=SC2046
    $AZ_TRACE network application-gateway create \
        --name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --max-capacity "$(gw_attr 'max_capacity')" \
        --min-capacity "$(gw_attr 'min_capacity')" \
        --capacity "$(gw_attr 'capacity')" \
        --frontend-port "$(gw_attr 'frontend_port')" \
        --http-settings-cookie-based-affinity "$(gw_attr 'http_settings_cookie_based_affinity')" \
        --http-settings-port "$(gw_attr 'http_settings_port')" \
        --http-settings-protocol "$(gw_attr 'http_settings_protocol')" \
        --http2 "$(gw_attr 'http2')" \
        --routing-rule-type "$(gw_attr 'routing_rule_type')" \
        --sku "$(gw_attr 'sku')" \
        $(options_list_if_present 'servers' 'servers') \
        $(options_list_if_present 'private-ip-address' 'private_ip_addresses') \
        $(options_list_if_present 'public-ip-address' 'public_ip_addresses') \
        $(options_list_if_present 'waf-policy' 'waf_policy') \
        $(certificate_options)
}

function foo () {
cat <<END
        --no-wait                             : Do not wait for the long-running operation to finish.
        --tags                                : Space-separated tags in 'key[=value]' format. Use '' to
                                                clear existing tags.
        --validate                            : Generate and validate the ARM template without creating
                                                any resources.
        --zones -z                            : Space-separated list of availability zones into which to
                                                provision the resource.  Allowed values: 1, 2, 3.
        --public-ip-address-allocation        : The kind of IP allocation to use when creating a new
                                                public IP.  Default: Dynamic.
        --subnet                              : Name or ID of the subnet. Will create resource if it
                                                does not exist. If name specified, also specify --vnet-
                                                name.  Default: default.
        --subnet-address-prefix               : The CIDR prefix to use when creating a new subnet.
                                                Default: 10.0.0.0/24.
        --vnet-address-prefix                 : The CIDR prefix to use when creating a new VNet.
                                                Default: 10.0.0.0/16.
        --vnet-name                           : The virtual network (VNet) name.

END

}

function foo2 () {
cat <<END2
az network application-gateway waf-config set --enabled {false, true}
                                              [--disabled-rule-groups]
                                              [--disabled-rules]
                                              [--exclusion]
                                              [--file-upload-limit]
                                              [--firewall-mode {Detection, Prevention}]
                                              [--gateway-name]
                                              [--ids]
                                              [--max-request-body-size]
                                              [--no-wait]
                                              [--request-body-check {false, true}]
                                              [--resource-group]
                                              [--rule-set-type]
                                              [--rule-set-version]
                                              [--subscription]
END2

}
function create_application_gateway_if_needed () {
    application_gateway_already_exists || deploy_application_gateway
}

create_application_gateway_if_needed

