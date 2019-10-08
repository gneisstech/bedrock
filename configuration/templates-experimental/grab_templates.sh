#!/usr/bin/env bash
#az resource show --resource-group CF-EXP --name atfcfexpdev --resource-type Microsoft.ContainerRegistry/registries > atfcfexpdev.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfadminapi --registry atfcfexpdev > webappatgcfadminapi.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfapp --registry atfcfexpdev > webappatgcfapp.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfauthproxy --registry atfcfexpdev > webappatgcfauthproxy.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfhealthapi --registry atfcfexpdev > webappatgcfhealthapi.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfingestapi --registry atfcfexpdev > webappatgcfingestapi.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfselfhealingapi --registry atfcfexpdev > webappatgcfselfhealingapi.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfselfhealingapp --registry atfcfexpdev > webappatgcfselfhealingapp.config.json
#az acr webhook get-config --resource-group CF-EXP --name webappatgcfvisualizationapi --registry atfcfexpdev > webappatgcfvisualizationapi.config.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfadminapi --registry atfcfexpdev > webappatgcfadminapi.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfapp --registry atfcfexpdev > webappatgcfapp.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfauthproxy --registry atfcfexpdev > webappatgcfauthproxy.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfhealthapi --registry atfcfexpdev > webappatgcfhealthapi.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfingestapi --registry atfcfexpdev > webappatgcfingestapi.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfselfhealingapi --registry atfcfexpdev > webappatgcfselfhealingapi.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfselfhealingapp --registry atfcfexpdev > webappatgcfselfhealingapp.json
#az acr webhook show --resource-group CF-EXP --name webappatgcfvisualizationapi --registry atfcfexpdev > webappatgcfvisualizationapi.json
#az resource show --resource-group CF-EXP --name CF-EXP-KV --resource-type Microsoft.KeyVault/vaults > CF-EXP-KV.json
#az resource show --resource-group CF-EXP --name atgcfexp-ag-post-auth --resource-type Microsoft.Network/applicationGateways > atgcfexp-ag-post-auth.json
#az resource show --resource-group CF-EXP --name atgcfexpag --resource-type Microsoft.Network/applicationGateways > atgcfexpag.json
#az resource show --resource-group CF-EXP --name atgcfexp-post-auth-pip --resource-type Microsoft.Network/publicIPAddresses > atgcfexp-post-auth-pip.json
#az resource show --resource-group CF-EXP --name atgcfexppip --resource-type Microsoft.Network/publicIPAddresses > atgcfexppip.json
#az resource show --resource-group CF-EXP --name atgcfexpag --resource-type Microsoft.Network/virtualNetworks > atgcfexpag_vnet.json
#az resource show --resource-group CF-EXP --name atgcfexp-sqls --resource-type Microsoft.Sql/servers > atgcfexp-sqls.json
#az sql db show --resource-group CF-EXP --name atgcfexp-admin --server atgcfexp-sqls > atgcfexp-admin.json
#az sql db show --resource-group CF-EXP --name atgcfexp-ingest --server atgcfexp-sqls > atgcfexp-ingest.json
#az sql db show --resource-group CF-EXP --name atgcfexp-self-healing --server atgcfexp-sqls > atgcfexp-self-healing.json
#az sql db show --resource-group CF-EXP --name atgcfexp-twin01-db --server atgcfexp-sqls > atgcfexp-twin01-db.json
#az sql db show --resource-group CF-EXP --name master --server atgcfexp-sqls > master.json
#az resource show --resource-group CF-EXP --name atgcfexpasp1 --resource-type Microsoft.Web/serverFarms > atgcfexpasp1.json
#az resource show --resource-group CF-EXP --name atgcfxlssp --resource-type Microsoft.Web/serverFarms > atgcfxlssp.json
#az resource show --resource-group CF-EXP --name atgcf-admin-api --resource-type Microsoft.Web/sites > atgcf-admin-api.json
#az resource show --resource-group CF-EXP --name atgcf-app --resource-type Microsoft.Web/sites > atgcf-app.json
#az resource show --resource-group CF-EXP --name atgcf-auth-proxy --resource-type Microsoft.Web/sites > atgcf-auth-proxy.json
#az resource show --resource-group CF-EXP --name atgcf-cf-self-healing --resource-type Microsoft.Web/sites > atgcf-cf-self-healing.json
#az resource show --resource-group CF-EXP --name atgcf-health-api --resource-type Microsoft.Web/sites > atgcf-health-api.json
#az resource show --resource-group CF-EXP --name atgcf-ingest-api --resource-type Microsoft.Web/sites > atgcf-ingest-api.json
#az resource show --resource-group CF-EXP --name atgcf-self-healing-api --resource-type Microsoft.Web/sites > atgcf-self-healing-api.json
#az resource show --resource-group CF-EXP --name atgcf-self-healing-app --resource-type Microsoft.Web/sites > atgcf-self-healing-app.json
#
az webapp config appsettings list --resource-group CF-EXP --name atgcf-admin-api > atgcf-admin-api.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-app > atgcf-app.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-auth-proxy > atgcf-auth-proxy.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-cf-self-healing > atgcf-cf-self-healing.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-health-api > atgcf-health-api.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-ingest-api > atgcf-ingest-api.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-self-healing-api > atgcf-self-healing-api.config.json
az webapp config appsettings list --resource-group CF-EXP --name atgcf-self-healing-app > atgcf-self-healing-app.config.json

az webapp config container show --resource-group CF-EXP --name atgcf-admin-api > atgcf-admin-api.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-app > atgcf-app.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-auth-proxy > atgcf-auth-proxy.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-cf-self-healing > atgcf-cf-self-healing.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-health-api > atgcf-health-api.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-ingest-api > atgcf-ingest-api.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-self-healing-api > atgcf-self-healing-api.container-settings.json
az webapp config container show --resource-group CF-EXP --name atgcf-self-healing-app > atgcf-self-healing-app.container-settings.json

az webapp config connection-string list --resource-group CF-EXP --name atgcf-admin-api > atgcf-admin-api.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-app > atgcf-app.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-auth-proxy > atgcf-auth-proxy.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-cf-self-healing > atgcf-cf-self-healing.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-health-api > atgcf-health-api.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-ingest-api > atgcf-ingest-api.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-self-healing-api > atgcf-self-healing-api.connection-strings.json
az webapp config connection-string list --resource-group CF-EXP --name atgcf-self-healing-app > atgcf-self-healing-app.connection-strings.json

