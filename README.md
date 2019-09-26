# Kubernetes

Terraform module to deploy a Kubernetes cluster on Azure by using the managed Kubernetes solution AKS. For security reasons it will only deploy a rbac enabled clusters and requires an Azure AD application for authenticating users. This account can be created with the module [avinor/kubernetes-azuread-integration/azurerm](https://github.com/avinor/terraform-azurerm-kubernetes-azuread-integration). Service principal required can be created with [avinor/service-principal/azurerm](https://github.com/avinor/terraform-azurerm-service-principal) module. It is not required to grant the service principal any roles, this module will make sure to grant required roles. That does however mean that the deployment has to run with Owner priviledges.

## Usage

This example deploys a simple cluster with one node pool. The service principal and Azure AD integration secrets need to be changed.

Example uses [tau](https://github.com/avinor/tau) for deployment.

```terraform
module {
    source = "avinor/kubernetes/azurerm"
    version = "1.0.02
}

inputs {
    name = "simple"
    resource_group_name = "simple-aks-rg"
    location = "westeurope"
    service_cidr = "10.0.0.0/24"
    kubernetes_version = "1.13.5"

    service_principal = {
        client_id = "00000000-0000-0000-0000-000000000000"
        client_secret = "00000000-0000-0000-0000-000000000000"
    }

    azure_active_directory = {
        client_app_id = "00000000-0000-0000-0000-000000000000"
        server_app_id = "00000000-0000-0000-0000-000000000000"
        server_app_secret = "00000000-0000-0000-0000-000000000000"
    }

    agent_pools = [
        {
            name = "linux"
            vnet_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1"
        },
    ]
}
```

If using tau to deploy the service principal and Azure AD integration secrets too it could be read from dependencies.

```terraform
dependency "service_principal" {
    # Created with azure/service-principal/azurerm module
    source = "./aks-service-principal.hcl"
}

dependency "azuread" {
    # Created with azure/kubernetes-azuread-integration/azurerm module
    source = "./aks-ad-integration.hcl"
}

module {
    source = "avinor/kubernetes/azurerm"
    version = "1.0.02
}

inputs {
    name = "simple"
    resource_group_name = "simple-aks-rg"
    location = "westeurope"
    service_cidr = "10.0.0.0/24"
    kubernetes_version = "1.13.5"

    service_principal = {
        client_id = dependency.service_principal.outputs.client_id
        client_secret = dependency.service_principal.outputs.client_secret
    }

    azure_active_directory = {
        client_app_id = dependency.azuread.outputs.client_app_id
        server_app_id = dependency.azuread.outputs.server_app_id
        server_app_secret = dependency.azuread.outputs.server_app_secret
    }

    agent_pools = [
        {
            name = "linux"
            vnet_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1"
        },
    ]
}
```

Similar to this the virtual network subnet id could also be retrieved from a dependency.

## Helm

Cluster does not come with Helm tiller installed. It does create a service account for tiller though. Once Helm v3 is released this will be removed and manual installation of tiller will not be required.

To initialize tiller without TLS run:

```bash
helm init --service-account tiller --node-selectors "beta.kubernetes.io/os"="linux"
```

If secure tiller is required look at [helm instructions](https://github.com/helm/helm/blob/master/docs/tiller_ssl.md) for setup.

## Dashboard

Currently the Kubernetes Dashboard does not support RBAC in a good way. There is an option in this module to turn on a read-only dashboard with variable `read_only_dashboard`. When set to true it will grant users access to read resources in Kubernetes from the dashboard, except secrets, but not modify in any way. Dashboard still has to be started by running `az aks browse` where users have to sign in.

## Available version

To get a list of available Kubernetes version in a region run the following command. Replace `westeurope` with region of choice.

```bash
az aks get-versions --location westeurope --query "orchestrators[].orchestratorVersion"
```

## Preview faetures

There are several preview features that can be used when creating the cluster. For some of the settings its required that those are set for cluster to work.

### Availability Zones

This feature is not recommended at the moment as it requires cluster to be created with a Standard Load Balancer, which has a public ip. Cluster should be secured behind a firewall and do not have a public ip at all. Until it can be created without a public ip this is not supported.

### Api server authorized ip range

Module supports setting this variable, but [preview](https://docs.microsoft.com/en-us/azure/aks/api-server-authorized-ip-ranges) has to be activated.

### Multiple Node Pools

For use with multiple node pools [enable this feature](https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools) before creating cluster.

## Roles

This module will assign the required roles for cluster. These are based on the [Microsoft documentation](https://docs.microsoft.com/en-us/azure/aks/kubernetes-service-principal). The variables `container_registries` and `storage_contributor` can be used to grant it access to container registries and storage accounts.

If cluster needs to manage some Managed Identities that can be done by using the input variable `managed_identities`. The AKS service principal will be granted `Managed Identity Operator` role to those identities.
