#!/usr/bin/env bash
az resource show --resource-group Web-CfDev --name http-echo-debugging --resource-type Microsoft.Web/sites > http-echo-debugging.logging.json
az webapp config appsettings list --resource-group Web-CfDev --name http-echo-debugging > http-echo-debugging.config.logging.json
az webapp config container show --resource-group Web-CfDev --name http-echo-debugging > http-echo-debugging.container-settings.logging.json
az webapp config connection-string list --resource-group Web-CfDev --name http-echo-debugging > http-echo-debugging.connection-strings.logging.json
az webapp log show --resource-group Web-CfDev --name http-echo-debugging > http-echo-debugging.logging.logging.json