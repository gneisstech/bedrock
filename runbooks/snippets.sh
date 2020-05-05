#!/usr/bin/env bash

kubectl --namespace kube-system get secret admin-user-token-x6lkp -o json | jq  '.data.token | @base64d'

cd configuration/k8s/charts/cf-deployment-umbrella/
rm Chart.lock
helm dependency build .

TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh


helm install cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

helm upgrade cfk8s ./configuration/k8s/charts/cf-deployment-umbrella --values <(TARGET_CONFIG=./configuration/environments/cf_k8s_ci.yaml ./recipes/extract_service_values.sh) --namespace cfk8s

docker build . -t cfqaregistry.azurecr.io/cf-objects-api-docker:r0.0.20-IndividualCI.20200428.3.RC

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
