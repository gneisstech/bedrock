#!/usr/bin/env bash

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

rg="CF-EXP"
waf="atgcfexpag"

az network application-gateway rewrite-rule set list --resource-group "${rg}" --gateway-name "${waf}" > rewrite_rule.atgcfexpag.json
return

az network application-gateway address-pool list --resource-group "${rg}" --gateway-name "${waf}" > address_pool_list.atgcfexpag.json
az network application-gateway auth-cert list --resource-group "${rg}" --gateway-name "${waf}" > auth_cert.atgcfexpag.json
az network application-gateway frontend-ip list --resource-group "${rg}" --gateway-name "${waf}" > frontend_ip.atgcfexpag.json
az network application-gateway frontend-port list --resource-group "${rg}" --gateway-name "${waf}" > frontend_port.atgcfexpag.json
az network application-gateway http-listener list --resource-group "${rg}" --gateway-name "${waf}" > http_listener.atgcfexpag.json
az network application-gateway http-settings list --resource-group "${rg}" --gateway-name "${waf}" > http_settings.atgcfexpag.json
az network application-gateway probe list --resource-group "${rg}" --gateway-name "${waf}" > probe.atgcfexpag.json
az network application-gateway redirect-config list --resource-group "${rg}" --gateway-name "${waf}" > redirect_config.atgcfexpag.json
az network application-gateway root-cert list --resource-group "${rg}" --gateway-name "${waf}" > root_cert.atgcfexpag.json
az network application-gateway rule list --resource-group "${rg}" --gateway-name "${waf}" > rule.atgcfexpag.json
az network application-gateway ssl-cert list --resource-group "${rg}" --gateway-name "${waf}" > ssl_cert.atgcfexpag.json
az network application-gateway url-path-map list --resource-group "${rg}" --gateway-name "${waf}" > url_path_map.atgcfexpag.json
az network application-gateway waf-policy list --resource-group "${rg}" > waf_policy.atgcfexpag.json
az network application-gateway show --resource-group "${rg}" --name "${waf}" > base_waf.atgcfexpag.json
az network application-gateway ssl-policy show --resource-group "${rg}" --gateway-name "${waf}" > ssl_policy.atgcfexpag.json
az network application-gateway waf-config show --resource-group "${rg}" --gateway-name "${waf}" > waf_config.atgcfexpag.json
