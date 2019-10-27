# Deployment of CF environments

## Deployment configuration

1) each environment is described by a yaml file containing configuration parameters
2) currently, we have:
    1) configuration/targets/cf_dev.yaml
    2) configuration/targets/cf_qa.yaml
    3) configuration/targets/cf_staging.yaml
3) to create a new environment, copy an existing environment config and change the environment specific settings
    1) as of 2019-10-24, those changes are: (yes, we will work to make it DRYer)
```
5c5
<     environment_name: &environmentName 'Dev'
---
>     environment_name: &environmentName 'QA'
7,9c7,9
<     default_azure_subscription: &defaultAzureSubscription '5649ad97-1fd3-460f-b569-9995bbb6c5c0'  # Acuity Brands, Inc. ConnectedFacilities-Dev
<     tls_cert_subscription: &subscription_tls '5e49f516-d005-4ae8-a287-031c8573401c'  # Acuity Brands, Inc. Allspice-Dev
<     dns_subscription: &subscription_dns '5e49f516-d005-4ae8-a287-031c8573401c'  # Acuity Brands, Inc. Allspice-Dev
---
>     default_azure_subscription: &defaultAzureSubscription '781c62dc-1612-43e6-a0ca-a8138888691f'  # Acuity Brands, Inc. ConnectedFacilities-QA
>     tls_cert_subscription: &subscription_tls 'a98f27b5-367a-44b6-af72-26fab4efc5f7'  # Acuity Brands, Inc. Allspice-QA
>     dns_subscription: &subscription_dns 'a98f27b5-367a-44b6-af72-26fab4efc5f7'  # Acuity Brands, Inc. Allspice-QA
14c14
<       # application_id: &appRegistrationID '3a6085d9-676a-473c-832f-b73b2b7f7561'  # Acuity Brands Atrius Dev UI
---
>       # application_id: &appRegistrationID '5aa2313f-7a76-4d43-9dc4-612ab69ef306'  # Acuity Brands Atrius QA UI
21c21
<       - name: &atriusDnsRG 'atriusops-allspicedev'
---
>       - name: &atriusDnsRG 'atriusops-allspiceqa'
23,24c23,24
<       # CF Dev resource groups
<       - name: &cfWafRG 'Waf-CfDev'
---
>       # CF QA resource groups
>       - name: &cfWafRG 'Waf-CfQA'
26c26
<       - name: &cfDbRG 'Data-CfDev'
---
>       - name: &cfDbRG 'Data-CfQA'
28c28
<       - name: &cfKeysRG 'Kv-CfDev'
---
>       - name: &cfKeysRG 'Kv-CfQA'
30c30
<       - name: &cfAcrRG 'Acr-CfDev'
---
>       - name: &cfAcrRG 'Acr-CfQA'
32c32
<       - name: &cfNetworksRG 'Vnet-CfDev'
---
>       - name: &cfNetworksRG 'Vnet-CfQA'
34c34
<       - name: &cfAppSvcRG 'Web-CfDev'
---
>       - name: &cfAppSvcRG 'Web-CfQA'
36c36
<       - name: &cfAuthNSvcRG 'Authn-CfDev'
---
>       - name: &cfAuthNSvcRG 'Authn-CfQA'
40c40
<         - name: &wafIP 'cf-dev-waf-pip'
---
>         - name: &wafIP 'cf-qa-waf-pip'
47c47
<         - name: &postAuthnIP 'cf-dev-post-auth-pip'
---
>         - name: &postAuthnIP 'cf-qa-post-auth-pip'
55c55
<         - zone: &dnsZone 'dev.atrius-iot.com'
---
>         - zone: &dnsZone 'qa.atrius-iot.com'
57c57
<           fqdn: 'cf.dev.atrius-iot.com.'
---
>           fqdn: 'cf.qa.atrius-iot.com.'
64c64
<         - name: 'cf-dev-vnet'
---
>         - name: 'cf-qa-vnet'
70c70
<             - name: 'cf-dev-0-subnet'
---
>             - name: 'cf-qa-0-subnet'
72c72
<             - name: 'cf-dev-1-subnet'
---
>             - name: 'cf-qa-1-subnet'
78c78
<       - name: &atriusKVName 'atrius01kvbxkbdsepg6'
---
>       - name: &atriusKVName 'atrius01kvjyfjczwcoo'
80,81c80,81
<       # CF Dev Key Vault
<       - name: &kvName 'cf-dev-master-kv'
---
>       # CF QA Key Vault
>       - name: &kvName 'cf-qa-master-kv'
87c87
<         - name: &cfDefaultDbServer 'cf-dev-sqls'
---
>         - name: &cfDefaultDbServer 'cf-qa-sqls'
90c90
<           admin_name: &cfDefaultDBAdminName 'cf-dev-sqls-admin-user'
---
>           admin_name: &cfDefaultDBAdminName 'cf-qa-sqls-admin-user'
94c94
<             secret_name: &cfDefaultDBSecretName 'admin-pw-for-cf-dev-sqls'
---
>             secret_name: &cfDefaultDBSecretName 'admin-pw-for-cf-qa-sqls'
102c102
<         - name: &selfHealingSchema 'cf-dev-self-healing'
---
>         - name: &selfHealingSchema 'cf-qa-self-healing'
116c116
<         - name: &healthSchema 'cf-dev-twin01-db'
---
>         - name: &healthSchema 'cf-qa-twin01-db'
145c145
<       - name: &authServiceFarm 'cf-dev-authservice-asp'
---
>       - name: &authServiceFarm 'cf-qa-authservice-asp'
152c152
<       - name: &webServiceFarm 'cf-dev-webservice-asp'
---
>       - name: &webServiceFarm 'cf-qa-webservice-asp'
160c160
<       - name: &primaryACR 'cfdevregistry'
---
>       - name: &primaryACR 'cfqaregistry'
163c163
<         uri: &uriPrimaryACR 'https://cfdevregistry.azurecr.io'
---
>         uri: &uriPrimaryACR 'https://cfqaregistry.azurecr.io'
171c171
<         - name: &cfAuthnService 'cf-dev-auth-proxy'
---
>         - name: &cfAuthnService 'cf-qa-auth-proxy'
179c179
<             name: 'cfdevauthproxywh'
---
>             name: 'cfqaauthproxywh'
186c186
<           upstreamHost: &postAuthnGateway 'cf-dev-post-authn-ag'
---
>           upstreamHost: &postAuthnGateway 'cf-qa-post-authn-ag'
203c203
<               - &oauthProxyClientSecretName 'atg-cf-dev-oauth2-proxy-client-secret'
---
>               - &oauthProxyClientSecretName 'atg-cf-qa-oauth2-proxy-client-secret'
213c213
<               - 'atg-cf-dev-oauth2-proxy-cookie-secret'
---
>               - 'atg-cf-qa-oauth2-proxy-cookie-secret'
269c269
<         - name: &cfHealthApp 'cf-dev-app'
---
>         - name: &cfHealthApp 'cf-qa-app'
277c277
<             name: 'cfdevappwh'
---
>             name: 'cfqaappwh'
317c317
<         - name: &cfHealthAdminApi 'cf-dev-admin-api'
---
>         - name: &cfHealthAdminApi 'cf-qa-admin-api'
325c325
<             name: 'cfdevadminapiwh'
---
>             name: 'cfqaadminapiwh'
382c382
<         - name: &cfHealthApi 'cf-dev-health-api'
---
>         - name: &cfHealthApi 'cf-qa-health-api'
390c390
<             name: 'cfdevhealthapiwh'
---
>             name: 'cfqahealthapiwh'
447c447
<         - name: &cfHealthIngestApi 'cf-dev-ingest-api'
---
>         - name: &cfHealthIngestApi 'cf-qa-ingest-api'
455c455
<             name: 'cfdevingestapiwh'
---
>             name: 'cfqaingestapiwh'
513c513
<         - name: &cfSelfHealingApp 'cf-dev-self-healing-app'
---
>         - name: &cfSelfHealingApp 'cf-qa-self-healing-app'
521c521
<             name: 'cfdevselfhealingappwh'
---
>             name: 'cfqaselfhealingappwh'
561c561
<         - name: &cfSelfHealingApi 'cf-dev-self-healing-api'
---
>         - name: &cfSelfHealingApi 'cf-qa-self-healing-api'
569c569
<             name: 'cfdevselfhealingapiwh'
---
>             name: 'cfqaselfhealingapiwh'
628c628
<       - name: 'cf-dev-waf-ag'
---
>       - name: 'cf-qa-waf-ag'
671c671
<           - name: 'wildcarddevatrius-iotcom'
---
>           - name: 'wildcardqaatrius-iotcom'
836c836
<           - name: &postAuthnUrlPathMap 'cf-dev-post-authn-path-map-001'
---
>           - name: &postAuthnUrlPathMap 'cf-qa-post-authn-path-map-001'
914c914
<         description: 'cf-dev-auth'  # unfortunately limited to 15 characters by AZ CLI
---
>         description: 'cf-qa-auth'  # unfortunately limited to 15 characters by AZ CLI

```

## Deployment script
1) login to azure from the command line with the following options from your user account:
    ```
    az login --allow-no-subscriptions
    ```
2) dry run the desired configuration and fix any errors or warnings
    ```
    TARGET_CONFIG=configuration/targets/cf_qa.yaml ./recipes/deploy_environment.sh 2>&1 | tee output_log.txt
    ```
   
3) deploy the desired configuration - it should run through completion if you have sufficient privileges to deploy
    ```
    TARGET_CONFIG=configuration/targets/cf_qa.yaml AZ_TRACE=az ./recipes/deploy_environment.sh 2>&1 | tee deploy_log.txt
    ```
4) manual steps to complete the deployment
    1) due to insufficient privileges on other shared resources (they are in a privileged AD tenant)
        1) create a new app password on the Atrius UI "application registration"
            1. navigate to
                `Acuity Brands Technical Services, INC - App registrations->Acuity Brands Atrius Dev UI`
                note that it is in a different subscription.   Change to Dev/QA/US as appropriate for deployment environment
            1. copy the client id from the "overview panel", you will need it later
            1. navigate to the `Certificates & secrets` panel
                1. add a new "Client Secret", name as `atg-cf-dev-oauth2-proxy-client-secret` (dev/qa/staging, etc)
                1. copy the value of the new secret while it is still visible
        1) put the new app password into the configuration of the AUTHN web app
            1. navigate to  `Home->Resource groups->Authn-CfDev->cf-dev-auth-proxy - Configuration`
            2. change the configuration option `OAUTH2_PROXY_CLIENT_SECRET` to have the new client secret
        1) put the new app password into the key vault for the deployment environment
            1. navigate to `Resource groups->Kv-CfDev->cf-dev-master-kv - Secrets->atg-cf-dev-oauth2-proxy-client-secret`
            1. click `add a new version`
            1. put the new client secret value into the value field
        1) put the new app clinet id into the configuration of the AUTHN web app
            1. navigate to  `Home->Resource groups->Authn-CfDev->cf-dev-auth-proxy - Configuration`
            2. change the configuration option `OAUTH2_PROXY_CLIENT_ID` to have the value of the client id from above
        2) create a new callback URL on the Atrius UI "application registration" (Authorizations)
            1. navigate to
                `Acuity Brands Technical Services, INC - App registrations->Acuity Brands Atrius Dev UI - Authentication`
                note that it is in a different subscription.   Change to Dev/QA/US as appropriate for deployment environment
        6) add another configuration variable "API_KEY" to the self-healing-api webapp, it's value is provided by the developer of the SHL_v1 service
            1. @@ TODO automation and placement of this secret in an Ops Keyvault that is shared across subscriptions
    1) due to insufficient privileges on other shared resources (they are in a privileged AD tenant)
        1) add or update DNS zone records to point to the public IP on the WAF
            
    2) due to AZ CLI lack of support for newer azure API (bind rewrite rules to routing rules on the AuthN AG)
        1) navigate in portal to resourcegroup Waf-CF{dev,qa,staging,prod} and open the cf-{env}-waf-ag
        2) navigate to rewrite rules, "security_headers"
        3) click the box to associate with "rule1"
        4) click "Next", click "Update"
    3) recent breaking changes (not yet automated -- represent tech debt if automated:
        1) navigate in portal to resourcegroup Waf-CF{dev,qa,staging,prod} and open the cf-{env}-waf-ag
        1) navigate to "Web Application Firewall"
        1) Turn off "inspect request body"
        1) save the change
    3) load any related seed data into the databases
        ```
        TARGET_CONFIG=./configuration/targets/cf_dev.yaml AZ_TRACE=az ./paas/recipes/import_database.sh cf-dev-twin01-db cfexp2bytelightsa db-snaps atg-cf-exp2-twin01-db-2019-10-24-14-15.bacpac
        ```
    4) seed the containers into the container registry
        1) revise origin and target Azure Registry container names in the file `./recipes/promote_containers.sh`
        2) run `./recipes/promote_containers.sh`
        3) the webhooks will start the web apps
    5) connect build pipelines to the container registry
        1) @@ TODO

5) wait a minute -- everything should be working  (https://foo.com/cf-app, https://foo.com/cf-self-healing )

6) miscellanea:
    1) may need to file a ticket to add the WAF public IP to the appropriate DNS zone (post deployment)
        1) prefer to do this as an "A Record Alias" to the public IP name rather than "A record" with IP, or CNAME
    2) may need to file a ticket to obtain TLS certificate for the desired host name (pre deployment)
        1) store the ticket in a privileged keyvault with a lifespan longer than that intended of the deployment
        2) update the config file with the location of the TLS certificate/secret
