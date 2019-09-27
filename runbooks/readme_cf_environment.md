# environment for CF health app

1) configure oauth in AD application
    1) example: `Acuity Brands Atrius Dev UI`
        1) tenant=`db566806-bf04-4296-98cc-ba6d2d950788`, AppID=`3a6085d9-676a-473c-832f-b73b2b7f7561`
        2) add reply URL to `Authentication`
        3) add new Client Secret to `Certificates & Secrets`
1) configure DNS
    1) add A record alias from `cf.[dev|qa|prod].atrius-iot.com` to WAF public IP name
1) configure TLS certificate
    1) extract from KeyVault and ensure intermediate certificates
1) configure resource groups
    1) Web Application Firewall
        1) lifecycle -- updated when web add is added or deleted, updated when TLS keys rotated
        1) resources

        | Resource Name | Life Cycle | Resource Group | Location | Type |
        |---------------|------------|----------------|----------|------|
        |atgcfexpag     |app add/delete|CF-EXP|           southcentralus|  Microsoft.Network/applicationGateways|
        |atgcfexppip    |app add/delete|CF-EXP|           southcentralus|  Microsoft.Network/publicIPAddresses|
        |atgcfexpag     |app add/delete|CF-EXP|           southcentralus|  Microsoft.Network/virtualNetworks|
        |atgcf-auth-proxy                         |app add/delete|CF-EXP|           southcentralus|  Microsoft.Web/sites|
        |atfcfexpdev/webappatgcfauthproxy         |app add/delete|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
        |atgcfexpasp1                             |app add/delete|CF-EXP|           southcentralus|  Microsoft.Web/serverFarms|

    1) Container Registry
        1) lifecycle -- longer than related web service resource group
        1) resources

        | Resource Name | Life Cycle | Resource Group | Location | Type |
        |---------------|------------|----------------|----------|------|
        |atfcfexpdev    |longer than Web Service resource group|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries|

    1) Database Server(s)
        1) lifecycle -- `infinite`, depends on product SLA
        1) regular backup
        1) HA - Active/Active failover multi-region GeoRedundant
        1) resources
    
            | Resource Name | Life Cycle | Resource Group | Location | Type |
            |---------------|------------|----------------|----------|------|
            |atgcfexp-sqls                            |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers|
            |atgcfexp-sqls/atgcfexp-admin             |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers/databases|
            |atgcfexp-sqls/atgcfexp-twin01-db         |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers/databases|
            |atgcfexp-sqls/atgcfexp-ingest            |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers/databases|
            |atgcfexp-sqls/atgcfexp-self-healing      |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers/databases|
            |atgcfexp-sqls/master                     |x|CF-EXP|           southcentralus|  Microsoft.Sql/servers/databases|

    1) Key Vault
        1) re-use existing atrius key vault
        1) lifecycle -- based on key rotation policy
        1) is used for:
            1) full-chain TLS certificate
            1) mssql server - database password
        1) resources
    
            | Resource Name | Life Cycle | Resource Group | Location | Type |
            |---------------|------------|----------------|----------|------|
            |CF-EXP-KV                                |deprecate|CF-EXP|           southcentralus|  Microsoft.KeyVault/vaults|

    1) Monitoring/Logging/Observability
        1) lifecycle -- longer than related web service resource group
        1) resources
        1) not activated for MVP (Oct 1, 2019)

    1) Web Services
        1) lifecycle -- `sprint`, regular updates (for dev, the lifecyle is `commit` per each service)
        1) HA - Active/Active failover multi-region GeoRedundant
        1) resources
    
            | Resource Name | Life Cycle | Resource Group | Location | Type |
            |---------------|------------|----------------|----------|------|
            |atgcfexp-ag-post-auth                    |x|CF-EXP|           southcentralus|  Microsoft.Network/applicationGateways|
            |atgcfexp-post-auth-pip                   |deprecate|CF-EXP|           southcentralus|  Microsoft.Network/publicIPAddresses|
            |atgcfxlssp                               |x|CF-EXP|           southcentralus|  Microsoft.Web/serverFarms|
            |atgcf-app                                |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atgcf-admin-api                          |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atgcf-health-api                         |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atgcf-ingest-api                         |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atgcf-self-healing-app                   |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atgcf-self-healing-api                   |x|CF-EXP|           southcentralus|  Microsoft.Web/sites|
            |atfcfexpdev/webappatgcfapp               |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
            |atfcfexpdev/webappatgcfadminapi          |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
            |atfcfexpdev/webappatgcfhealthapi         |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
            |atfcfexpdev/webappatgcfingestapi         |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
            |atfcfexpdev/webappatgcfselfhealingapp    |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|
            |atfcfexpdev/webappatgcfselfhealingapi    |x|CF-EXP|           southcentralus|  Microsoft.ContainerRegistry/registries/webhooks|

1) Separate Git Respository for each Web Service
    1) add Devops Pipeline to each repo for "commit -> cloud (Dev)"
    1) add manual approval to promote "cloud (Dev) -> cloud (QA)"
        1) will `tag` the release commit with semver
        1) will copy Docker container from Dev registry to QA registry
            1) add meta-data to container
    1) add manual approval to promote "cloud (QA) -> cloud (PROD)"
        1) will `tag` the release commit with semver
        1) will copy Docker container from QA registry to Prod registry
            1) add meta-data to container
            
1) devops pipeline:
    1) build
    2) test
    3) code quality
    4) SAST
    5) DAST
    6) automatic dependency scans
    7) automatic license compliance
    8) automatic container scanning
    9) automatic review
    10) automatic deployment
    11) automatic browser performance testing
    12) automatic monitoring
