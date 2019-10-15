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

function gw_attr_size () {
    local -r attr="${1}"
    gw_attr "${attr}" | jq -r -e 'length // 0'
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
cat > /dev/null <<END3
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

function option_if_present () {
    local -r option_key="${1}"
    local -r option_config="${2}"
    local option_length
    option_length="$(gw_attr "${option_config}" | jq -r -e 'length')"
    if [[ '0' != "${option_length}" ]]; then
        printf -- "--%s %s" "${option_key}" "$(gw_attr "${option_config}" )"
    fi
    true
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
    local length
    length="$(gw_attr_size 'tls_certificate')"
    if [[ '0' != "${length}" ]]; then
        echo "--cert-file <( pfx_certificate \"\${password}\")"
        echo "--cert-password \"\${password}\""
    fi
}

function create_application_gateway () {
    local password
    password="$(random_key)"

    # shellcheck disable=SC2046,SC2086
    eval $AZ_TRACE network application-gateway create \
        --name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --capacity "$(gw_attr 'capacity')" \
        --frontend-port "$(gw_attr 'frontend_port')" \
        --http-settings-cookie-based-affinity "$(gw_attr 'http_settings_cookie_based_affinity')" \
        --http-settings-port "$(gw_attr 'http_settings_port')" \
        --http-settings-protocol "$(gw_attr 'http_settings_protocol')" \
        --http2 "$(gw_attr 'http2')" \
        --sku "$(gw_attr 'sku')" \
        $(option_if_present 'max-capacity' 'max_capacity') \
        $(option_if_present 'min-capacity' 'min_capacity') \
        $(options_list_if_present 'servers' 'servers') \
        $(options_list_if_present 'private-ip-address' 'private_ip_addresses') \
        $(options_list_if_present 'public-ip-address' 'public_ip_addresses') \
        $(options_list_if_present 'waf-policy' 'waf_policy') \
        $(cert_file_options)
}

function set_waf_config () {
    if [[ '0' != "$(gw_attr_size 'waf_config')" ]]; then
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

function address_pool_names () {
    gw_attr 'address_pools' | jq -r -e ' . | @tsv'
}

function address_pools () {
    if [[ '0' != "$(gw_attr_size 'address_pools')" ]]; then
        local server
        for server in $(address_pool_names); do
            # basic strategy is one address pool per server type, and one server type per address pool
            $AZ_TRACE network application-gateway address-pool create \
                --gateway-name "$(application_gateway_name)" \
                --resource-group "$(application_gateway_resource_group)" \
                --name "${server}-pool" \
                --servers "${server}"
        done
    fi
}

function authentication_certificates_option () {
    if [[ '0' != "$(gw_attr_size 'http_settings.authenticationCertificates')" ]]; then
        echo "--auth-certs "
        gw_attr 'http_settings.authenticationCertificates' | jq -r -e '. | @tsv' 2> /dev/null
    fi
}

function trusted_root_certificates_option () {
    if [[ '0' != "$(gw_attr_size 'http_settings.trustedRootCertificates')" ]]; then
        echo "--root-certs"
        gw_attr 'http_settings.trustedRootCertificates' | jq -r -e '. | @tsv' 2> /dev/null
    fi
}

function http_settings () {
    if [[ '0' != "$(gw_attr_size 'http_settings')" ]]; then
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
    if [[ '0' != "$(gw_attr_size 'probe')" ]]; then
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

function ssl_policy_cipher_suites () {
    if [[ '0' != "$(gw_attr_size 'tls_policy.cipherSuites')" ]]; then
        local cipher_option="--cipher-suites"
        local cipher_suite
        for cipher_suite in $(cipher_suites); do
            cipher_option="${cipher_option} ${cipher_suite}"
        done
        echo "${cipher_option}"
    fi
}

function set_ssl_policy () {
    if [[ '0' != "$(gw_attr_size 'tls_policy')" ]]; then
        # shellcheck disable=SC2046
        $AZ_TRACE network application-gateway ssl-policy set \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --policy-type  "$(gw_attr 'tls_policy.policyType')" \
            --min-protocol-version  "$(gw_attr 'tls_policy.minProtocolVersion')" \
            $(ssl_policy_cipher_suites)
    fi
}

function rewrite_rule_set_attr () {
    local -r rule_set_name="${1}"
    local -r attr="${2}"
    gw_attr 'rewrite_rule_sets[]' | jq -r -e "select(.name == \"${rule_set_name}\" ) | .${attr}"
}

function rewrite_rule_set_rule_names () {
    local -r rule_set_name="${1}"
    rewrite_rule_set_attr "${rule_set_name}" 'rewriteRules[]' | jq -r -e '[ .name ] | @tsv'
}

function rewrite_rule_set_rule_attr () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local -r attr="${3}"
    rewrite_rule_set_attr "${rule_set_name}" 'rewriteRules[]' \
        | jq -r -e "select(.name == \"${rule_name}\" ) | .${attr}"
}

function rewrite_rule_set_rule_attr_length () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local -r attr="${3}"
    rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" "${attr}"  | jq -r -e '. | length'
}

function escape_option_values () {
    # shellcheck disable=SC1003
    sed -E "s|([ ;:'])|#\1|g" | tr '#' '\'
}

function request_headers_option_value () {
    rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" 'actionSet.requestHeaderConfigurations' | jq -r -e '.[] | [ "\(.headerName)=\(.headerValue)" ] | @tsv'
}

function request_headers_option () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local length
    length="$(rewrite_rule_set_rule_attr_length  "${rule_set_name}" "${rule_name}" 'actionSet.requestHeaderConfigurations')"
    if [[ '0' != "${length}" ]]; then
        echo "--request-headers"
    fi
}

function request_headers_values () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local length
    length="$(rewrite_rule_set_rule_attr_length  "${rule_set_name}" "${rule_name}" 'actionSet.requestHeaderConfigurations')"
    if [[ '0' != "${length}" ]]; then
        printf "%s" "$(request_headers_option_value | escape_option_values)"
    fi
}

function response_headers_option_value () {
    rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" 'actionSet.responseHeaderConfigurations' | jq -r -e '.[] | [ "\(.headerName)=\(.headerValue)" ] | @tsv'
}

function response_headers_option () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local length
    length="$(rewrite_rule_set_rule_attr_length "${rule_set_name}" "${rule_name}" 'actionSet.responseHeaderConfigurations')"
    if [[ '0' != "${length}" ]]; then
        echo '--response-headers'
    fi
}

function response_headers_values () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local length
    length="$(rewrite_rule_set_rule_attr_length "${rule_set_name}" "${rule_name}" 'actionSet.responseHeaderConfigurations')"
    if [[ '0' != "${length}" ]]; then
        printf '%s' "$(response_headers_option_value | escape_option_values)"
    fi
}

function create_rewrite_ruleset_rule () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local -a header_args=()
    header_args[${#header_args[@]}]="$(request_headers_option "${rule_set_name}" "${rule_name}")"
    header_args[${#header_args[@]}]="$(request_headers_values "${rule_set_name}" "${rule_name}")"
    header_args[${#header_args[@]}]="$(response_headers_option "${rule_set_name}" "${rule_name}")"
    header_args[${#header_args[@]}]="$(response_headers_values "${rule_set_name}" "${rule_name}")"

    # shellcheck disable=SC2046,SC2086
    eval $AZ_TRACE network application-gateway rewrite-rule create \
        --gateway-name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --rule-set-name "${rule_set_name}" \
        --name "${rule_name}" \
        --sequence "$(rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" 'ruleSequence')" \
        "${header_args[@]}"
}

function create_rewrite_ruleset_rule_conditions () {
    local -r rule_set_name="${1}"
    local -r rule_name="${2}"
    local length
    length="$(rewrite_rule_set_rule_attr_length "${rule_set_name}" "${rule_name}" 'conditions')"
    if [[ '0' != "${length}" ]]; then
        local i
        for i in $(seq 0 $(( length - 1)) ); do
            # shellcheck disable=SC2046
            $AZ_TRACE network application-gateway rewrite-rule condition create \
                --gateway-name "$(application_gateway_name)" \
                --resource-group "$(application_gateway_resource_group)" \
                --rule-set-name "${rule_set_name}" \
                --rule-name "${rule_name}" \
                --variable "$(rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" "conditions[${i}].variable" )" \
                --ignore-case "$(rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" "conditions[${i}].ignoreCase")" \
                --negate "$(rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}"  "conditions[${i}].negate" )" \
                --pattern "$(rewrite_rule_set_rule_attr "${rule_set_name}" "${rule_name}" "conditions[${i}].pattern")"
        done
    fi
}

function create_rewrite_rules () {
    local -r rule_set_name="${1}"
    local rule_name
    for rule_name in $(rewrite_rule_set_rule_names "${rule_set_name}"); do
        create_rewrite_ruleset_rule "${rule_set_name}" "${rule_name}"
        create_rewrite_ruleset_rule_conditions "${rule_set_name}" "${rule_name}" || (echo  "boom!" > /dev/stderr)
    done
}

function rewrite_rule_set_names () {
    gw_attr 'rewrite_rule_sets[]' | jq -r -e '[ .name ]| @tsv'
}

function create_rewrite_rule_set () {
    local -r rule_set_name="${1}"
    $AZ_TRACE network application-gateway rewrite-rule set create \
        --gateway-name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --name "${rule_set_name}"
}

function rewrite_rules () {
    if [[ '0' != "$(gw_attr_size 'rewrite_rule_sets')" ]]; then
        local rule_set_name
        for rule_set_name in $(rewrite_rule_set_names); do
            create_rewrite_rule_set "${rule_set_name}"
            create_rewrite_rules "${rule_set_name}"
        done
    fi
}

function url_path_map_attr () {
    local -r url_path_map_name="${1}"
    local -r attr="${2}"
    gw_attr 'url_path_maps[]' | jq -r -e "select(.name == \"${url_path_map_name}\" ) | .${attr}"
}

function url_path_map_rule_redirect () {
    local url_path_map_name="${1}"
    local index="${2}"
    local redirect_config
    redirect_config="$(url_path_map_attr "${url_path_map_name}" "pathRules[${index}].redirectConfiguration")"
    if [[ "null" != "${redirect_config}" ]]; then
        echo "--redirect-config ${redirect_config}"
    fi
}

function url_path_map_rule1_redirect () {
    local url_path_map_name="${1}"
    url_path_map_rule_redirect "${url_path_map_name}" '0'
}

function url_path_map_paths () {
    local url_path_map_name="${1}"
    local index="${2}"
    url_path_map_attr "${url_path_map_name}" "pathRules[${index}].paths" | jq -e -r '. | @tsv'
}

function url_path_map_rule_paths () {
    local url_path_map_name="${1}"
    local index="${2}"
    local paths
    paths="$(url_path_map_paths "${url_path_map_name}" "${index}")"
    echo "--paths ${paths}"
}

function url_path_map_rule1_paths () {
    local url_path_map_name="${1}"
    url_path_map_rule_paths "${url_path_map_name}" '0'
}

function create_remaining_path_rules () {
    local url_path_map_name="${1}"
    local rule_count
    rule_count="$(url_path_map_attr "${url_path_map_name}" "pathRules" | jq -r -e 'length')"
    if [[ "1" != "${rule_count}" ]]; then
        for index in $(seq 1 $(( rule_count - 1 ))); do
        # @@ TODO FIXME "-pool"
        # shellcheck disable=SC2046
        $AZ_TRACE network application-gateway url-path-map rule create \
            --gateway-name "$(application_gateway_name)" \
            --resource-group "$(application_gateway_resource_group)" \
            --path-map-name "${url_path_map_name}" \
            --name "$(url_path_map_attr "${url_path_map_name}" "pathRules[${index}].name" )"  \
            --address-pool "$(url_path_map_attr "${url_path_map_name}" "pathRules[${index}].backendAddressPool" )-pool"  \
            --http-settings "$(url_path_map_attr "${url_path_map_name}" "pathRules[${index}].backendHttpSettings" )" \
            $(url_path_map_rule_redirect "${url_path_map_name}" "${index}") \
            $(url_path_map_rule_paths "${url_path_map_name}" "${index}")
        done
    fi
}

function create_url_path_map () {
    local url_path_map_name="${1}"

    # @@ TODO FIXME "-pool"
    # shellcheck disable=SC2046
    $AZ_TRACE network application-gateway url-path-map create \
        --gateway-name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --name "${url_path_map_name}" \
        --rule-name "$(url_path_map_attr "${url_path_map_name}" 'pathRules[0].name' )"  \
        --address-pool "$(url_path_map_attr "${url_path_map_name}" 'pathRules[0].backendAddressPool' )-pool"  \
        --http-settings "$(url_path_map_attr "${url_path_map_name}" 'pathRules[0].backendHttpSettings' )" \
        $(url_path_map_rule1_redirect "${url_path_map_name}") \
        $(url_path_map_rule1_paths "${url_path_map_name}")
    create_remaining_path_rules "${url_path_map_name}"
}

function url_path_map_names () {
    gw_attr 'url_path_maps' | jq -r -e '.[] | [ .name ] | @tsv'
}

function url_path_maps () {
    if [[ '0' != "$(gw_attr_size 'url_path_maps')" ]]; then
        local url_path_map_name
        for url_path_map_name in $(url_path_map_names); do
            echo "checkpoint path_map_name: [${url_path_map_name}]"
            create_url_path_map "${url_path_map_name}"
        done
    fi
}

function routing_rule_attr () {
    local -r routing_rule_name="${1}"
    local -r attr="${2}"
    gw_attr 'requestRoutingRules[]' | jq -r -e "select(.name == \"${routing_rule_name}\" ) | .${attr}"
}

function create_routing_rule () {
    local routing_rule_name="${1}"

    # shellcheck disable=SC2046
    $AZ_TRACE network application-gateway rule create \
        --gateway-name "$(application_gateway_name)" \
        --resource-group "$(application_gateway_resource_group)" \
        --name "${routing_rule_name}-routing" \
        --rule-type "$(routing_rule_attr "${routing_rule_name}" 'properties.ruleType' )"  \
        --url-path-map "$(routing_rule_attr "${routing_rule_name}" 'properties.urlPathMap' )"
}

function routing_rule_names () {
    gw_attr 'request_routing_rules' | jq -r -e '.[] | [ .name ] | @tsv'
}

function request_routing_rules () {
    if [[ '0' != "$(gw_attr_size 'request_routing_rules')" ]]; then
        local routing_rule_name
        for routing_rule_name in $(routing_rule_names); do
            echo "checkpoint routing_rule_name: [${routing_rule_name}]"
            create_routing_rule "${routing_rule_name}"
        done
    fi
    true
}

#
# https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-url-redirect-powershell
#
function deploy_application_gateway () {
    echo "checkpoint create_application_gateway" > /dev/stderr
    create_application_gateway
    echo "checkpoint set_waf_config" > /dev/stderr
    set_waf_config
}

function update_application_gateway_config () {
    echo "checkpoint address_pool"
    address_pools
    echo "checkpoint set_probe"
    set_probe
    echo "checkpoint http_settings"
    http_settings
    echo "checkpoint rewrite_rules"
    rewrite_rules
    echo "checkpoint set_ssl_policy"
    set_ssl_policy
    echo "checkpoint url_path_map"
    url_path_maps
    echo "checkpoint routing rules"
    request_routing_rules

    ####################
    # we are using the following defaults created by "application-gateway create"
    # auth_cert
    # front_end_ip
    # front_end_port
    # http_listener
    # redirect-config
    # root_cert
    # ssl_cert
    # waf_policy
}

function create_application_gateway_if_needed () {
    application_gateway_already_exists || deploy_application_gateway
    update_application_gateway_config
}

create_application_gateway_if_needed
