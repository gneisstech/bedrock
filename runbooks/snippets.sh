#!/usr/bin/env bash

kubectl --namespace kube-system get secret admin-user-token-x6lkp -o json | jq  '.data.token | @base64d'

cd configuration/k8s/charts/cf-deployment-umbrella/
rm Chart.lock
helm dependency build .

TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh
TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml AZ_TRACE=az ./recipes/deploy_environment.sh

helm install cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm upgrade cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

docker build . -t cfqaregistry.azurecr.io/cf-objects-api-docker:r0.0.20-IndividualCI.20200428.3.RC

helm install datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_datadog_values.sh) --namespace datadog
helm upgrade datadog stable/datadog --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_datadog_values.sh) --namespace datadog

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

# attach azure container registry to cluster
az aks update -n myAKSCluster -g myResourceGroup --attach-acr <acrName>
az aks update -n cf-ci-k8s-001 -g k8s-cfci --attach-acr /subscriptions/781c62dc-1612-43e6-a0ca-a8138888691f/resourceGroups/Acr-CfQA/providers/Microsoft.ContainerRegistry/registries/cfqaregistry


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

az acr helm push -n MyRegistry mychart-0.3.2.tgz --force

The command is `kubectl --namespace datadog exec datadog-bplwr -it datadog-cluster-agent -- flare 342217` and this case ID is 342217.
