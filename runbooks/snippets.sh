#!/usr/bin/env bash

kubectl --namespace kube-system get secret admin-user-token-x6lkp -o json | jq  '.data.token | @base64d'

cd configuration/k8s/charts/cf-deployment-umbrella/
rm -f Chart.lock *.tgz
helm dependency build .

TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh
TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml AZ_TRACE=az ./recipes/deploy_environment.sh
TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml AZ_TRACE=az ./recipes/deploy_environment.sh
TARGET_CONFIG=./configuration/environments/cf_k8s_qa.yaml AZ_TRACE=az ./recipes/deploy_environment.sh
TARGET_CONFIG=./configuration/environments/cf_k8s_prod.yaml AZ_TRACE=az ./recipes/deploy_environment.sh

helm install cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s
helm upgrade cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm install cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s
helm upgrade cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm install cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml ./recipes/extract_service_values.sh) --namespace cfk8s
helm upgrade cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm install cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_qa.yaml ./recipes/extract_service_values.sh) --namespace cfk8s
helm upgrade cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_qa.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm install cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_prod.yaml ./recipes/extract_service_values.sh) --namespace cfk8s
helm upgrade cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_prod.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

docker build . -t cfqaregistry.azurecr.io/cf-objects-api-docker:r0.0.20-IndividualCI.20200428.3.RC

helm install datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_datadog_values.sh) --namespace datadog
helm upgrade datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_datadog_values.sh) --namespace datadog

helm install datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml ./recipes/extract_datadog_values.sh) --namespace datadog
helm upgrade datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml ./recipes/extract_datadog_values.sh) --namespace datadog

helm install datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_qa.yaml ./recipes/extract_datadog_values.sh) --namespace datadog
helm upgrade datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_qa.yaml ./recipes/extract_datadog_values.sh) --namespace datadog

helm install datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_prod.yaml ./recipes/extract_datadog_values.sh) --namespace datadog
helm upgrade datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_prod.yaml ./recipes/extract_datadog_values.sh) --namespace datadog

#dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl proxy
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.

#metrics
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

#metrics server helm chart
https://github.com/helm/charts/tree/master/stable/metrics-server


# clean before install
kubectl delete clusterrole cf-waf-ingress
kubectl delete clusterrolebinding cf-waf-ingress
kubectl --namespace cfk8s delete secret waf-tls-secret

# attach azure container registry to cluster
az aks update -n cf-ci-k8s-001 -g k8s-cfci --attach-acr /subscriptions/781c62dc-1612-43e6-a0ca-a8138888691f/resourceGroups/Acr-CfQA/providers/Microsoft.ContainerRegistry/registries/cfqaregistry
az aks update -n cf-ci-k8s-001 -g k8s-cfci --attach-acr /subscriptions/5649ad97-1fd3-460f-b569-9995bbb6c5c0/resourceGroups/Acr-CfDev/providers/Microsoft.ContainerRegistry/registries/cfdevregistry

az aks update -n cf-qa-k8s-001 -g k8s-cfqa --attach-acr /subscriptions/5649ad97-1fd3-460f-b569-9995bbb6c5c0/resourceGroups/Acr-CfDev/providers/Microsoft.ContainerRegistry/registries/cfdevregistry
az aks update -n cf-prod-k8s-001 -g k8s-cfprod --attach-acr /subscriptions/5649ad97-1fd3-460f-b569-9995bbb6c5c0/resourceGroups/Acr-CfDev/providers/Microsoft.ContainerRegistry/registries/cfdevregistry

environments:
clean-local
local
clean-azure-dev
azure-dev
qa
staging
prod

containers:
waitfor each schema
migrate each schema

umbrella-helm:
with overrides from local helms

local:
manage helm chart version - semver in Chart.yaml
manage docker container version tags
manage local helm umbrella


###
az acr helm repo add -n cfdevregistry
helm repo update
helm search repo cfdevregistry --devel


az acr helm push -n MyRegistry mychart-0.3.2.tgz --force
az acr helm push -n cfdevregistry cf-deployment-umbrella-1.0.6-dev.tgz

The command is `kubectl --namespace datadog exec datadog-bplwr -it datadog-cluster-agent -- flare 342217` and this case ID is 342217.

az aks update -n myAKSCluster -g myResourceGroup --attach-acr <acr-resource-id>

==============================

### incantations for jesse
az acr helm install-cli
# install kubernetes?  "brew" (not sure if above command from AZ does this)
az acr helm repo add -n cfdevregistry
helm repo update
helm search repo cfdevregistry --devel
## repeat previous 2 steps until you see the new chart for the service you just build
# pull the latest master-bytelight from cf_devops repository
az aks get-credentials --resource-group k8s-cfdev --name cf-dev-k8s-001
kubectl config use-context cf-dev-k8s-001-admin # this may be redundant from above
helm upgrade cfk8s cfdevregistry/cf-deployment-umbrella --version ^1.0.0-0 --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_dev.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

==============================
kubectl get secrets --namespace kube-system  -o json |jq '.items[] | select(.metadata.annotations."kubernetes.io/service-account.name" == "admin-user") | .metadata.name'
kubectl get secrets --namespace kube-system  -o json |jq '.items[] | select(.metadata.annotations."kubernetes.io/service-account.name" == "admin-user") | .data.token | @base64d'

==============================
kubectl --context cf-dev-k8s-001-admin --namespace cfk8s get pods -o json |jq -r '.items[].metadata.name' | grep -E 'admin|authz|health|elm' | xargs -n 1 -I {} kubectl --context cf-dev-k8s-001-admin --namespace cfk8s exec {} rake routes > rails_routes.txt
