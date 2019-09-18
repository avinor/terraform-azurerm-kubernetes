# Kubernetes

This module will deploy a Kubernetes cluster in Azure (AKS). Module is intentionally not named aks as it should abstract away the actual implementation. The module will deploy a Kubernetes cluster in the way best suited for Azure.

## Preview features

Public ip
https://docs.microsoft.com/en-us/azure/aks/load-balancer-standard

az aks get-versions --location westeurope --query "orchestrators[].orchestratorVersion"


https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic


helm secure
https://github.com/helm/helm/blob/master/docs/tiller_ssl.md

https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm

helm init --service-account tiller --node-selectors "beta.kubernetes.io/os"="linux"


Microsoft.ContainerService/MultiAgentpoolPreview