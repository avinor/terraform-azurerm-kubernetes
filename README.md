# Kubernetes

This module will deploy a Kubernetes cluster in Azure (AKS). Module is intentionally not named aks as it should abstract away the actual implementation. The module will deploy a Kubernetes cluster in the way best suited for Azure.

## Preview features

https://docs.microsoft.com/en-us/azure/aks/load-balancer-standard

az aks get-versions --location westeurope --query "orchestrators[].orchestratorVersion"