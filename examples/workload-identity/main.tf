module "workload-identity" {
  source = "../../"

  name                = "workload-identity"
  resource_group_name = "workload-identity-aks-rg"
  location            = "westeurope"
  service_cidr        = "10.241.0.0/24"
  kubernetes_version  = "1.27.3"

  agent_pools = [
    {
      name                 = "linux"
      orchestrator_version = "1.27.3"
      vnet_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mygroup1/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/mysub"
    },
  ]

  workload_identities = {
    identity_name = {
      service_account_name      = "identity-sa"
      service_account_namespace = "identity-namespace"
      role_assignments = {
        acr_pull = {
          scope = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerRegistry/registries/myregistry"
          name  = "AcrPull"
        },
        k8s_contributor = {
          scope = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-k8s-cluster"
          name  = "Contributor"
        }
      }
    }
  }
}