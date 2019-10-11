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

function random_key () {
    hexdump -n 27 -e '"%02X"'  /dev/urandom
}

function application_gateway_already_exists () {
    az network application-gateway show \
        --name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        > /dev/null 2>&1
}

function foo3 () {
cat <<END3
az network application-gateway --help

Group
    az network application-gateway : Manage application-level routing and load balancing services.
        To learn more about Application Gateway, visit https://docs.microsoft.com/azure/application-
        gateway/application-gateway-create-gateway-cli.

Subgroups:
    address-pool        : Manage address pools of an application gateway.
    auth-cert           : Manage authorization certificates of an application gateway.
    frontend-ip         : Manage frontend IP addresses of an application gateway.
    frontend-port       : Manage frontend ports of an application gateway.
    http-listener       : Manage HTTP listeners of an application gateway.
    http-settings       : Manage HTTP settings of an application gateway.
    probe               : Manage probes to gather and evaluate information on a gateway.
    redirect-config     : Manage redirect configurations.
    rewrite-rule        : Manage rewrite rules of an application gateway.
    root-cert           : Manage trusted root certificates of an application gateway.
    rule                : Evaluate probe information and define routing rules.
    ssl-cert            : Manage SSL certificates of an application gateway.
    ssl-policy          : Manage the SSL policy of an application gateway.
    url-path-map        : Manage URL path maps of an application gateway.
    waf-config          : Configure the settings of a web application firewall.
    waf-policy          : Manage application gateway web application firewall (WAF) policies.

Commands:
    create              : Create an application gateway.
    delete              : Delete an application gateway.
    list                : List application gateways.
    show                : Get the details of an application gateway.
    show-backend-health : Get information on the backend health of an application gateway.
    start               : Start an application gateway.
    stop                : Stop an application gateway.
    update              : Update an application gateway.
    wait                : Place the CLI in a waiting state until a condition of the application
                          gateway is met.
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

function get_original_cert_from_shared_vault () {
    $AZ_TRACE keyvault secret show \
        --vault-name "$(gw_attr 'tls_certificate.origin.vault_name')" \
        --name "$(gw_attr 'tls_certificate.origin.tls_secret_name')" \
        2> /dev/null \
    | jq -r '.value'
}

function pkcs12_to_pem () {
    base64 --decode | openssl pkcs12 -nodes -in /dev/stdin -passin 'pass:'
}

function fail_empty_set () {
    grep -q '^'
}

function has_intermediate_pem () {
    local -r pem="${1}"
    local -r entrust_certificate_name='Subject:.*CN=Entrust Certification Authority - L1K'
    echo "${pem}" | openssl x509 -noout -text | grep "${entrust_certificate_name}" | fail_empty_set
}

function get_issuer_intermediate_cert_url () {
    openssl x509 -noout -text | grep 'CA Issuers - URI:' | sed -e 's|.*URI:||'
}

function get_intermediate_pem () {
    local -r url="${1}"
    curl -sS "${url}" | openssl x509 -inform der -in /dev/stdin -out /dev/stdout
}

function add_intermediate_certificate () {
    local pem issuer_intermediate_cert_url intermediate_pem
    pem="$(cat /dev/stdin)"
    echo "${pem}"
    if ! has_intermediate_pem "${pem}"; then
        issuer_intermediate_cert_url="$(echo "${pem}" | get_issuer_intermediate_cert_url)"
        intermediate_pem="$(get_intermediate_pem "${issuer_intermediate_cert_url}" )"
        echo "${intermediate_pem}"
    fi
}

function sign_as_pfx () {
    local -r pem="${1}"
    local -r password="${2}"
    local tmpFile
    tmpFile="$(mktemp)"
    echo "${pem}" > "${tmpFile}"
    openssl pkcs12 -export -out /dev/stdout -in "${tmpFile}" -passout "pass:${password}"
    rm "${tmpFile}"
}

function pfx_certificate () {
    local password="${1}"
    local pem
    pem=$(get_original_cert_from_shared_vault | pkcs12_to_pem | add_intermediate_certificate)
    sign_as_pfx "${pem}" "${password}"
}

function cert_file_options () {
    if [[ "0" != "$(gw_attr_size 'tls_certificate')" ]]; then
        echo "--cert-file <( pfx_certificate \"\${password}\")"
        echo "--cert-password \"\${password}\""
    fi
}

function create_application_gateway () {
    local password
    password="$(random_key)"

    # shellcheck disable=SC2046
    eval $AZ_TRACE network application-gateway create \
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
        $(cert_file_options)
}

function set_waf_config () {
    if [[ "0" != "$(gw_attr_size 'waf_config')" ]]; then
        $AZ_TRACE network application-gateway waf-config set \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --enabled "$(gw_attr 'waf_config.enabled')" \
            --file-upload-limit "$(gw_attr 'waf_config.file_upload_limit')" \
            --firewall-mode "$(gw_attr 'waf_config.firewall_mode')" \
            --max-request-body-size "$(gw_attr 'waf_config.max_request_body_size')" \
            --request-body-check "$(gw_attr 'waf_config.request_body_check')" \
            --rule-set-type "$(gw_attr 'waf_config.rule_set_type')" \
            --rule-set-version "$(gw_attr 'waf_config.rule_set_version')"
    else
        $AZ_TRACE network application-gateway waf-config set \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --enabled false
    fi
}

function gw_attr_size () {
    local -r attr="${1}"
    gw_attr "${attr}" | jq -r -e 'length // 0'
}

function authentication_certificates_option () {
    if [[ "0" != "$(gw_attr_size 'http_settings.authenticationCertificates')" ]]; then
        echo "--auth-certs "
        gw_attr 'http_settings.authenticationCertificates' | jq -r -e '. | @tsv' 2> /dev/null
    fi
}

function trusted_root_certificates_option () {
    if [[ "0" != "$(gw_attr_size 'http_settings.trustedRootCertificates')" ]]; then
        echo "--root-certs"
        gw_attr 'http_settings.trustedRootCertificates' | jq -r -e '. | @tsv' 2> /dev/null
    fi
}

function http_settings () {
    if [[ "0" != "$(gw_attr_size 'http_settings')" ]]; then
        #  shellcheck disable=SC2046
        $AZ_TRACE network application-gateway http-settings create \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --name "$(gw_attr 'http_settings.name')" \
            --port "$(gw_attr 'http_settings.port')" \
            --affinity-cookie-name "$(gw_attr 'http_settings.affinityCookieName')" \
            $(authentication_certificates_option) \
            --connection-draining-timeout "$(gw_attr 'http_settings.connectionDraining')" \
            --cookie-based-affinity "$(gw_attr 'http_settings.cookieBasedAffinity')" \
            --enable-probe "$(gw_attr 'http_settings.probeEnabled')" \
            --host-name-from-backend-pool "$(gw_attr 'http_settings.pickHostNameFromBackendAddress')" \
            --path "$(gw_attr 'http_settings.path')" \
            --probe "$(gw_attr 'http_settings.probe.name')" \
            --protocol "$(gw_attr 'http_settings.protocol')" \
            $(trusted_root_certificates_option) \
            --timeout "$(gw_attr 'http_settings.requestTimeout')"
    fi
}

function match_status_codes () {
    gw_attr 'probe.match.statusCodes' | jq -r -e '. | @tsv' 2> /dev/null
}

function set_probe () {
    if [[ "0" != "$(gw_attr_size 'probe')" ]]; then
        $AZ_TRACE network application-gateway probe create \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --name "$(gw_attr 'probe.name')" \
            --path "$(gw_attr 'probe.path')" \
            --protocol "$(gw_attr 'probe.protocol')" \
            --host-name-from-http-settings "$(gw_attr 'probe.pickHostNameFromBackendHttpSettings')" \
            --interval "$(gw_attr 'probe.interval')" \
            --match-body "$(gw_attr 'probe.match.body')" \
            --match-status-codes "$(match_status_codes)" \
            --min-servers "$(gw_attr 'probe.minServers')" \
            --threshold "$(gw_attr 'probe.unhealthyThreshold')" \
            --timeout "$(gw_attr 'probe.timeout')"
    fi
}

function cipher_suites () {
    gw_attr 'tls_policy.cipherSuites' | jq -r -e '. | @tsv' 2> /dev/null
}

function set_ssl_policy () {
    if [[ "0" != "$(gw_attr_size 'tls_policy')" ]]; then
        $AZ_TRACE network application-gateway ssl-policy set \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --name "$(gw_attr 'tls_policy.name')" \
            --cipher-suites  "$(cipher_suites)" \
            --min-protocol-version  "$(gw_attr 'tls_policy.minProtocolVersion')" \
            --policy-type  "$(gw_attr 'tls_policy.policyType')"
    fi
}

function url_path_map () {
    if [[ "0" != "$(gw_attr_size 'url_path_map')" ]]; then
        true
    fi
}

#
# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-url-redirect-powershell
#
function deploy_application_gateway () {
    create_application_gateway
}

function update_application_gateway_config () {
set -x
    set_waf_config
    http_settings
    set_probe
    # rewrite_rules
    # ssl_cert
    set_ssl_policy
    url_path_map

    ####################
    # we are using the following defaults created by "application-gateway create"
    # front_end_ip
    # http_listener
    # redirect-config
    # request_routing_rules
}

function create_application_gateway_if_needed () {
    application_gateway_already_exists || deploy_application_gateway
    update_application_gateway_config
}

create_application_gateway_if_needed

